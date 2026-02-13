from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, date
from database import supabase
from dependencies import get_current_user
from utils import is_invalid_user

router = APIRouter(prefix="/weight", tags=["Weight"])

# Schemas
from typing import List, Optional, Union, Any

# Schemas
class WeightEntrySchema(BaseModel):
    id: str
    weight: float
    difference: Optional[float] = 0.0
    created_at: Union[str, datetime]

class AddWeightSchema(BaseModel):
    user_id: str
    weight: float
    # Optional fields to direct update user_profiles if needed, 
    # but frontend said "these changes must be recorded in DB" implies history.
    
class WeightHistoryResponse(BaseModel):
    history: List[WeightEntrySchema]
    current_weight: float
    start_weight: Optional[float] = 0.0
    target_weight: Optional[float] = None
    weekly_change_goal: Optional[float] = None
    estimated_end_date: Optional[Union[str, date]] = None

@router.get("/history/{user_id}", response_model=WeightHistoryResponse)
async def get_weight_history(user_id: str, current_user_id: str = Depends(get_current_user)):
    user_id = user_id.strip()
    if is_invalid_user(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")
        
    # 1. Get Nutrition Data (where weight lives now)
    try:
        # Fetch from user_nutrition
        profile_res = supabase.table("user_nutrition").select("*").eq("user_id", user_id).single().execute()
        profile = profile_res.data
    except Exception as e:
        # If no nutrition entry, fallback or empty (should exist)
        profile = {} 
        print(f"Nutrition profile not found or error: {e}")

    # 2. Get History
    try:
        history_res = supabase.table("weight_history")\
            .select("*")\
            .eq("user_id", user_id)\
            .order("created_at", desc=True)\
            .execute()
        history = history_res.data
    except Exception as e:
        history = []
        print(f"Error fetching history: {e}")

    
    # helper to ensure float
    def to_float(val):
        if val is None: return 0.0
        try: return float(val)
        except: return 0.0

    current_w = to_float(profile.get("weight"))
    
    # Calculate start weight
    # If profile.start_weight (not in nutrition, maybe history?)
    # actually start_weight isn't in user_nutrition schema I saw earlier, 
    # but let's assume valid logic for now: last history item.
    start_w_candidate = None # profile.get("start_weight") is likely removed or not in new schema
    
    if start_w_candidate is None:
        if history:
            start_w_candidate = history[-1]["weight"]
        else:
            start_w_candidate = current_w
            
    start_w = to_float(start_w_candidate)

    return {
        "history": history,
        "current_weight": current_w,
        "start_weight": start_w,
        "target_weight": profile.get("target_weight"),
        "weekly_change_goal": profile.get("weekly_change_goal"),
        "estimated_end_date": profile.get("estimated_end_date")
    }

@router.post("/add")
async def add_weight_entry(data: AddWeightSchema, current_user_id: str = Depends(get_current_user)):
    data.user_id = data.user_id.strip()
    if is_invalid_user(data.user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")

    try:
        # 1. Get latest weight to calculate difference
        # We can look at weight_history OR user_nutrition. 
        # History is safer for 'difference'.
        latest_res = supabase.table("weight_history")\
            .select("weight")\
            .eq("user_id", data.user_id)\
            .order("created_at", desc=True)\
            .limit(1)\
            .execute()
            
        previous_weight = data.weight
        if latest_res.data:
            previous_weight = latest_res.data[0]["weight"]
            
        difference = data.weight - previous_weight

        # 2. Add to History
        new_entry = {
            "user_id": data.user_id,
            "weight": data.weight,
            "difference": difference,
            "created_at": datetime.utcnow().isoformat()
        }
        supabase.table("weight_history").insert(new_entry).execute()

        # 3. Update Current Weight in User Nutrition
        # Note: using user_id key to find the row
        supabase.table("user_nutrition").update({"weight": data.weight}).eq("user_id", data.user_id).execute()

        return {"status": "success", "message": "Weight recorded", "difference": difference}

    except Exception as e:
        print(f"Error adding weight: {e}")
        raise HTTPException(status_code=500, detail=str(e))
