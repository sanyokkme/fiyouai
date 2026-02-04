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
    if is_invalid_user(data.user_id): return {"status": "error", "message": "User logout"}
    update_data = {data.field: data.value}
    if data.field in ['height', 'weight', 'age']: 
        update_data[data.field] = int(float(data.value))
    
    service.user_repo.update_profile(data.user_id, update_data)
    return {"status": "success", "updated_fields": update_data}

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