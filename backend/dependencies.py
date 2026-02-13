from fastapi import Header, HTTPException
from jose import jwt
from config import settings
from database import supabase
from repositories.user_repo import UserRepository
from repositories.meal_repo import MealRepository
from services.nutrition_service import NutritionService


# JWT AUTH
def get_current_user(authorization: str = Header(...)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Token")
    token = authorization.replace("Bearer ", "")
    try:
        # Validate via Supabase directly to avoid algorithm mismatch (ES256 vs HS256)
        user_res = supabase.auth.get_user(token)
        if not user_res or not user_res.user:
            raise Exception("User verification failed")
        return user_res.user.id
    except Exception as e:
        print(f"Auth Error: {e}")
        # Fallback for dev: try to decode without verify if manual verify failed (OPTIONAL)
        # But for now, returning 401 is correct security.
        raise HTTPException(status_code=401, detail="Invalid Token")

# DI
def get_nutrition_service():
    return NutritionService(MealRepository(supabase), UserRepository(supabase))