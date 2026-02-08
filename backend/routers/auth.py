from fastapi import APIRouter, HTTPException, Depends
from schemas import RegisterSchema, LoginSchema, PasswordResetSchema, ProfileSetupSchema
from database import supabase
from services.nutrition_service import NutritionService
from dependencies import get_nutrition_service
from utils import get_now_poland, is_invalid_user
from datetime import datetime
from schemas import UpdatePasswordSchema
from services.auth_service import get_current_user

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.post("/register")
async def register(data: RegisterSchema, service: NutritionService = Depends(get_nutrition_service)):
    user_id = None
    try:
        res = supabase.auth.sign_up({"email": data.email, "password": data.password})
        if not res.user: raise HTTPException(status_code=400, detail="Error creating user")
        user_id = res.user.id

        dob = data.profile.dob
        age = 25
        if dob:
            try: age = (datetime.now() - datetime.strptime(dob.split('T')[0], "%Y-%m-%d")).days // 365
            except: pass

        db_profile = {
            "id": user_id, 
            "email": data.email, 
            "name": data.profile.name or data.email.split('@')[0],
            "weight": float(data.profile.weight),      # ✅ float для ваги
            "height": int(data.profile.height),        # ✅ int для росту
            "age": int(age),
            "gender": data.profile.gender,
            "goal": data.profile.goal,
            "activity_level": data.profile.activity,   # ✅ ваш новий рядок
            "created_at": get_now_poland().isoformat()
        }
        service.user_repo.create_profile(db_profile)
        return {"status": "success", "user_id": user_id}

    except Exception as e:
        if user_id: 
            try: supabase.auth.admin.delete_user(user_id)
            except: pass
        raise e

@router.post("/login")
async def login(data: LoginSchema):
    try:
        res = supabase.auth.sign_in_with_password({"email": data.email, "password": data.password})
        if res.session:
            return {"user_id": res.user.id, "email": res.user.email, "access_token": res.session.access_token}
    except Exception: pass
    raise HTTPException(status_code=400, detail="Login failed")
