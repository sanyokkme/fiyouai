from fastapi import Header, HTTPException
from jose import jwt
from config import settings
from database import supabase
from repositories.user_repo import UserRepository
from repositories.meal_repo import MealRepository
from services.nutrition_service import NutritionService


# --- JWT AUTH (з твого старого auth_service.py) ---
def get_current_user(authorization: str = Header(...)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Token")
    token = authorization.replace("Bearer ", "")
    try:
        payload = jwt.decode(token, settings.SUPABASE_JWT_SECRET, algorithms=["HS256"], audience="authenticated")
        return payload["sub"]
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid Token")

# --- DI ---
def get_nutrition_service():
    return NutritionService(MealRepository(supabase), UserRepository(supabase))