from fastapi import APIRouter, HTTPException, Depends, Form, UploadFile, File
from schemas import ProfileUpdateSchema
from services.nutrition_service import NutritionService
from dependencies import get_nutrition_service, get_current_user
from database import supabase
from utils import is_invalid_user, get_now_poland

router = APIRouter(prefix="/profile", tags=["Profile"])

@router.get("/private_tips")
async def get_private_tips(current_user_id: str = Depends(get_current_user)):
    return {"status": "success", "tip": "Слідкуйте за раціоном!", "user_id": current_user_id}

@router.post("/update")
async def update_profile(data: ProfileUpdateSchema, service: NutritionService = Depends(get_nutrition_service)):
    if is_invalid_user(data.user_id): 
        return {"status": "error", "message": "User logout"}
    
    update_data = {data.field: data.value}
    
    if data.field in ['height', 'age']: 
        update_data[data.field] = int(float(data.value))
    elif data.field in ['weight', 'body_fat', 'target_weight', 'weekly_change_goal']:
        update_data[data.field] = float(data.value)
    
    try:
        service.user_repo.update_profile(data.user_id, update_data)
        return {"status": "success", "updated_fields": update_data}
    except Exception as e:
        print(f"Database Error: {e}")
        # Повертаємо 500, щоб Flutter зрозумів, що щось не так
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{user_id}")
async def get_profile(user_id: str, service: NutritionService = Depends(get_nutrition_service)):
    if is_invalid_user(user_id): raise HTTPException(status_code=404)
    return service.user_repo.get_profile(user_id).data

@router.post("/avatar")
async def upload_avatar(user_id: str = Form(...), file: UploadFile = File(...), service: NutritionService = Depends(get_nutrition_service)):
    if is_invalid_user(user_id): raise HTTPException(status_code=400)
    contents = await file.read()
    path = f"{user_id}/avatar_{int(get_now_poland().timestamp())}.jpg"
    supabase.storage.from_("avatars").upload(path, contents, {"content-type": "image/jpeg"})
    url = supabase.storage.from_("avatars").get_public_url(path)
    service.user_repo.update_profile(user_id, {"avatar_url": url})
    return {"avatar_url": url}

@router.post("/change_password")
async def change_password(data: dict, service: NutritionService = Depends(get_nutrition_service)):
    """
    Змінює пароль користувача.
    Вимагає старий пароль для верифікації.
    """
    user_id = data.get('user_id')
    old_password = data.get('old_password')
    new_password = data.get('new_password')
    
    if is_invalid_user(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")
    
    if not old_password or not new_password:
        raise HTTPException(status_code=400, detail="Old and new passwords are required")
        
    try:
        # 1. Отримуємо email користувача для верифікації старого пароля
        # Спробуємо отримати з Auth (надійніше)
        try:
            auth_user = supabase.auth.admin.get_user_by_id(user_id)
            if auth_user and auth_user.user:
                email = auth_user.user.email
            else:
                raise Exception("User not found in Auth")
        except Exception:
            # Fallback to local DB
            profile = service.user_repo.get_profile(user_id)
            if not profile.data:
                raise HTTPException(status_code=404, detail="User not found")
            email = profile.data.get('email')

        # 2. Верифікуємо старий пароль
        try:
            auth_response = supabase.auth.sign_in_with_password({
                "email": email,
                "password": old_password
            })
            if not auth_response.user or not auth_response.session:
                 raise HTTPException(status_code=401, detail="Невірний старий пароль")
        except Exception:
            raise HTTPException(status_code=401, detail="Невірний старий пароль")
            
        # 3. Оновлюємо пароль використовуючи сесію користувача (так як Admin API недоступний)
        try:
            # Створюємо тимчасового клієнта, щоб діяти від імені користувача
            from supabase import create_client
            from config import settings
            
            # Використовуємо ключ, який є (навіть якщо service_role, ми будемо діяти як user)
            user_client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
            
            # Встановлюємо сесію, яку ми щойно отримали при перевірці старого пароля
            user_client.auth.set_session(
                auth_response.session.access_token,
                auth_response.session.refresh_token
            )
            
            # Оновлюємо пароль від імені самого користувача
            update_result = user_client.auth.update_user({"password": new_password})
            
            return {
                "status": "success",
                "message": "Пароль успішно змінено."
            }
            
        except Exception as e:
            print(f"Password update error: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to update password: {str(e)}")

    except HTTPException:
        raise
    except Exception as e:
        print(f"Change password error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/delete")
async def delete_account(user_id: str, service: NutritionService = Depends(get_nutrition_service)):
    """
    Повне видалення акаунту користувача:
    1. Видалення файлів з Storage
    2. Видалення профілю з БД
    3. Видалення користувача з Auth
    """
    if is_invalid_user(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")

    try:
        # 1. Видалення файлів з Storage
        try:
            # Отримуємо об'єкт StorageFileApi для бакета 'avatars'
            storage = supabase.storage.from_("avatars")
            # List повертає список об'єктів
            files = storage.list(user_id)
            
            if files:
                # Формуємо список шляхів для видалення
                # files має структуру [{'name': '...', ...}, ...]
                files_to_remove = [f"{user_id}/{f['name']}" for f in files]
                storage.remove(files_to_remove)
                print(f"🗑️ Deleted {len(files_to_remove)} files from storage for {user_id}")
                
        except Exception as e:
            print(f"⚠️ Storage delete error (non-critical): {e}")

        # 2. Видалення профілю з БД
        try:
            # Використовуємо table().delete()
            service.user_repo.db.table("user_nutrition").delete().eq("user_id", user_id).execute()
            service.user_repo.db.table("user_profiles").delete().eq("id", user_id).execute()
            print(f"✅ Deleted profile from DB for {user_id}")
        except Exception as e:
            print(f"DB delete error: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to delete profile: {e}")

        # 3. Видалення з Auth (Admin API)
        try:
            # Admin API дозволяє видалити користувача
            supabase.auth.admin.delete_user(user_id)
            print(f"✅ Deleted user from Auth for {user_id}")
        except Exception as e:
            print(f"Auth delete error: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to delete auth user: {e}")

        return {
            "status": "success", 
            "message": "Акаунт успішно видалено"
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Delete account error: {e}")
        raise HTTPException(status_code=500, detail=str(e))