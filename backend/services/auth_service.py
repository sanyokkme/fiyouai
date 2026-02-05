from fastapi import HTTPException, Header
from database import supabase
from config import settings
from jose import jwt
from datetime import datetime

def register_user(email: str, password: str, profile_data: dict = None) -> dict:
    try:
        response = supabase.auth.sign_up({"email": email, "password": password})
        
        if response.user:
            user_id = response.user.id
            
            return {"status": "ok", "user_id": user_id}
            
        raise HTTPException(status_code=400, detail="Помилка реєстрації")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

def login_user(email: str, password: str) -> dict:
    try:
        response = supabase.auth.sign_in_with_password({"email": email, "password": password})
        if response.session:
            return {
                "status": "ok", 
                "access_token": response.session.access_token,
                "user_id": response.user.id
            }
        raise HTTPException(status_code=401, detail="Невірні облікові дані")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

def get_current_user(authorization: str = Header(...)) -> str:
    """Декодування JWT токена для ідентифікації користувача в захищених запитах"""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Відсутній або невірний заголовок авторизації")
        
    token = authorization.replace("Bearer ", "")
    try:
        payload = jwt.decode(
            token, 
            settings.SUPABASE_JWT_SECRET, 
            algorithms=["HS256"], 
            audience="authenticated"
        )
        return payload["sub"] 
    except Exception:
        raise HTTPException(status_code=401, detail="Токен недійсний або термін дії закінчився")