from fastapi import APIRouter, HTTPException, Depends
from schemas import RegisterSchema, LoginSchema, PasswordResetSchema, ProfileSetupSchema, TokenResponse, RefreshTokenSchema
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
            "activity_level": data.profile.activity_level,
            "target_weight": data.profile.target_weight,
            "weekly_change_goal": data.profile.weekly_change_goal,
            "estimated_end_date": data.profile.estimated_end_date,
            "body_fat": data.profile.body_fat,
            "created_at": get_now_poland().isoformat()
        }
        service.user_repo.create_profile(db_profile)
        
        # 🆕 Create initial weight history entry
        # This ensures "Start Weight" is recorded in history immediately
        try:
            initial_history = {
                "user_id": user_id,
                "weight": float(data.profile.weight),
                "difference": 0.0,
                "created_at": get_now_poland().isoformat()
            }
            supabase.table("weight_history").insert(initial_history).execute()
        except Exception as e:
            print(f"Error creating initial weight history: {e}")
            # Non-critical, continue
            
        response_data = {"status": "success", "user_id": user_id}
        if res.session:
            response_data["access_token"] = res.session.access_token
            response_data["refresh_token"] = res.session.refresh_token
            
        return response_data

    except Exception as e:
        if user_id: 
            try: supabase.auth.admin.delete_user(user_id)
            except: pass
        raise e

@router.post("/login", response_model=TokenResponse)
async def login(data: LoginSchema):
    try:
        res = supabase.auth.sign_in_with_password({"email": data.email, "password": data.password})
        if res.session:
            return {
                "user_id": res.user.id, 
                "email": res.user.email, 
                "access_token": res.session.access_token,
                "refresh_token": res.session.refresh_token,
                "token_type": "bearer"
            }
    except Exception: pass
    raise HTTPException(status_code=400, detail="Login failed")

@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(data: RefreshTokenSchema):
    try:
        # Supabase refresh_session method
        res = supabase.auth.refresh_session(data.refresh_token)
        if res.session:
             return {
                "user_id": res.user.id, 
                "email": res.user.email, 
                "access_token": res.session.access_token,
                "refresh_token": res.session.refresh_token,
                "token_type": "bearer"
            }
    except Exception as e:
        print(f"Refresh error: {e}")
        pass
        
    raise HTTPException(status_code=401, detail="Invalid refresh token")
