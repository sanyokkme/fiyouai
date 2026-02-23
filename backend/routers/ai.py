import io
import uuid
import json
from PIL import Image
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Form
from fastapi.responses import JSONResponse
from services.ai_service import ai_service_instance
from services.nutrition_service import NutritionService
from dependencies import get_nutrition_service
from database import supabase
from utils import is_invalid_user, clean_to_int, clean_to_float, get_now_poland

router = APIRouter(tags=["AI"])

@router.post("/analyze_meal")
async def analyze_meal(file: UploadFile = File(...), user_id: str = Form(...), service: NutritionService = Depends(get_nutrition_service)):
    """Аналізує фото і ОДРАЗУ зберігає в історію."""
    if is_invalid_user(user_id): raise HTTPException(status_code=400, detail="Invalid User ID")
    
    contents = await file.read()
    path = f"{user_id}/{uuid.uuid4()}.jpg"
    supabase.storage.from_("meal-images").upload(path, contents)
    
    res = ai_service_instance.get_calories_from_image(Image.open(io.BytesIO(contents)).convert("RGB"))
    
    db_data = {
        "user_id": user_id,
        "calories": clean_to_int(res.get("calories")),
        "protein": clean_to_float(res.get("protein")),
        "fat": clean_to_float(res.get("fat")),
        "carbs": clean_to_float(res.get("carbs")),
        "food_items": res.get("food_items", []),
        "image_url": supabase.storage.from_("meal-images").get_public_url(path),
        "created_at": get_now_poland().isoformat()
    }
    service.meal_repo.add_meal(db_data)
    return db_data

@router.post("/analyze_image")
async def analyze_image_only(user_id: str = Form(...), file: UploadFile = File(...)):
    """Тільки аналізує фото (для прев'ю), нічого не зберігає в БД."""
    try:
        contents = await file.read()
        img = Image.open(io.BytesIO(contents)).convert("RGB")
        
        result = ai_service_instance.get_calories_from_image(img)
        
        print(f"AI Result: {json.dumps(result, indent=2, ensure_ascii=False)}")
        
        return result
    except Exception as e:
        return JSONResponse(status_code=500, content={"detail": str(e)})

from pydantic import BaseModel

class AnalyzeTextRequest(BaseModel):
    user_id: str
    text: str
    save_to_db: bool = False

@router.post("/analyze_text")
async def analyze_text(request: AnalyzeTextRequest, service: NutritionService = Depends(get_nutrition_service)):
    """Аналізує текст з голосу і зберігає в історію, якщо save_to_db == True."""
    if is_invalid_user(request.user_id): raise HTTPException(status_code=400, detail="Invalid User ID")
    
    try:
        res = ai_service_instance.analyze_food_text(request.text)
        
        db_data = {
            "user_id": request.user_id,
            "calories": clean_to_int(res.get("calories")),
            "protein": clean_to_float(res.get("protein")),
            "fat": clean_to_float(res.get("fat")),
            "carbs": clean_to_float(res.get("carbs")),
            "food_items": [res.get("meal_name", "Нова страва")],
            "image_url": None,
            "created_at": get_now_poland().isoformat()
        }
        
        if request.save_to_db:
            service.meal_repo.add_meal(db_data)
        
        # Include meal_name in return specifically for UI
        db_data['meal_name'] = res.get("meal_name", "Нова страва")
        
        return db_data
    except Exception as e:
        return JSONResponse(status_code=500, content={"detail": str(e)})

@router.get("/generate_recipe/{user_id}")
async def generate_recipe(user_id: str, service: NutritionService = Depends(get_nutrition_service)):
    user_id = user_id.strip()
    if is_invalid_user(user_id): raise HTTPException(status_code=400, detail="User not logged in")
    
    status = service.get_daily_status(user_id)
    rec = ai_service_instance.generate_personalized_recipe(
        remaining_cal=status.get("remaining", 500), 
        preferences=[], 
        goal=status.get("goal", "maintain")
    )
    
    if not rec: raise HTTPException(status_code=500, detail="AI failed")
    return rec

@router.get("/get_tips/{user_id}")
async def get_tips(user_id: str, service: NutritionService = Depends(get_nutrition_service)):
    user_id = user_id.strip()
    if is_invalid_user(user_id): 
        return {"summary": "", "tips": []}

    try:
        history, profile = service.get_data_for_tips(user_id)
        return ai_service_instance.get_weekly_insights(
            history=history,
            target=profile.get("daily_calories_target", 2000),
            goal=profile.get("goal", "maintain")
        )
    except Exception:
        return {"summary": "Слідкуйте за раціоном!", "tips": []}