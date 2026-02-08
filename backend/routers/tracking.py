from fastapi import APIRouter, HTTPException, Depends, Query
# ДОДАВ: ProfileUpdateSchema в імпорти
from schemas import WaterLogSchema, ManualMealSchema, SaveRecipeSchema, AddFromRecipeSchema, ProfileUpdateSchema, VitaminSchema
from services.nutrition_service import NutritionService
from dependencies import get_nutrition_service
from utils import is_invalid_user, get_now_poland, clean_to_int, clean_to_float
from datetime import datetime 
from database import supabase
import requests
import httpx 
import asyncio

router = APIRouter(tags=["Tracking"])


@router.get("/user_status/{user_id}")
async def get_user_status(user_id: str, service: NutritionService = Depends(get_nutrition_service)):
    if is_invalid_user(user_id):
        return {"eaten": 0, "target": 2000, "remaining": 0, "goal": "maintain"}
    return service.get_daily_status(user_id)

@router.get("/analytics/{user_id}")
async def get_analytics(user_id: str, service: NutritionService = Depends(get_nutrition_service)):
    if is_invalid_user(user_id): return []
    return service.get_weekly_analytics(user_id)

@router.post("/add_water")
async def add_water(data: WaterLogSchema, service: NutritionService = Depends(get_nutrition_service)):
    if is_invalid_user(data.user_id): raise HTTPException(status_code=400, detail="Invalid User")
    entry = {"user_id": data.user_id, "amount": data.amount, "created_at": data.created_at or get_now_poland().isoformat()}
    service.meal_repo.add_water(entry)
    return {"status": "success"}

@router.post("/add_meal")
async def add_meal(data: ManualMealSchema, service: NutritionService = Depends(get_nutrition_service)):
    if is_invalid_user(data.user_id): raise HTTPException(status_code=400, detail="Invalid User ID")
    entry = {
        "user_id": data.user_id,
        "calories": data.calories, "protein": data.protein, 
        "fat": data.fat, "carbs": data.carbs, 
        "meal_name": data.meal_name, 
        "image_url": data.image_url, 
        "created_at": get_now_poland().isoformat()
    }
    service.meal_repo.add_meal(entry)
    return {"status": "success", "data": entry}

@router.post("/save_recipe")
async def save_recipe(data: SaveRecipeSchema, service: NutritionService = Depends(get_nutrition_service)):
    if is_invalid_user(data.user_id): raise HTTPException(status_code=400, detail="Invalid User")
    
    title = data.title or data.recipe_name or "Новий рецепт"
    entry = {
        "user_id": data.user_id,
        "title": title,
        "calories": clean_to_int(data.calories),
        "protein": clean_to_float(data.protein),
        "fat": clean_to_float(data.fat),
        "carbs": clean_to_float(data.carbs),
        "ingredients": data.ingredients or [],
        "instructions": data.instructions or [],
        "time": data.time,
        "created_at": get_now_poland().isoformat()
    }
    service.meal_repo.save_recipe(entry)
    return {"status": "success"}

@router.get("/saved_recipes/{user_id}")
async def get_saved_recipes(user_id: str, service: NutritionService = Depends(get_nutrition_service)):
    if is_invalid_user(user_id): return []
    return service.meal_repo.get_saved_recipes(user_id).data

@router.delete("/delete_recipe/{recipe_id}")
async def delete_recipe(recipe_id: str, service: NutritionService = Depends(get_nutrition_service)):
    service.meal_repo.delete_recipe(recipe_id)
    return {"status": "success"}

@router.post("/add_from_recipe")
async def add_from_recipe(data: AddFromRecipeSchema, service: NutritionService = Depends(get_nutrition_service)):
    if is_invalid_user(data.user_id): raise HTTPException(status_code=400, detail="Invalid User")
    
    r = data.recipe
    
    entry = {
        "user_id": data.user_id,
        "meal_name": r.get("recipe_name") or r.get("title") or "Рецепт",
        "calories": clean_to_int(r.get("calories")),
        "protein": clean_to_float(r.get("protein") or r.get("proteins")),
        "fat": clean_to_float(r.get("fat") or r.get("fats")),
        "carbs": clean_to_float(r.get("carbs") or r.get("carbohydrates")),
        "created_at": datetime.now().isoformat()
    }
    
    service.meal_repo.add_meal(entry)
    return {"status": "success"}

@router.post("/add_manual_meal")
async def add_manual_meal(meal: ManualMealSchema, service: NutritionService = Depends(get_nutrition_service)):
    try:
        meal_data = {
            "user_id": meal.user_id,
            "meal_name": meal.meal_name, 
            "calories": meal.calories,
            "protein": meal.protein,
            "fat": meal.fat,
            "carbs": meal.carbs,
            "created_at": meal.created_at,
            "image_url": meal.image_url 
        }

        result = service.meal_repo.add_meal(meal_data)
        return {"status": "success", "data": result.data}

    except Exception as e:
        print(f"Error adding manual meal: {e}")
        raise HTTPException(status_code=500, detail=str(e))       

@router.post("/add_custom_food_product")
async def add_custom_food_product(product: dict):
    """
    Додає власний продукт користувача в таблицю food_products.
    """
    try:
        # Валідація обов'язкових полів
        if not product.get('name'):
            raise HTTPException(status_code=400, detail="Product name is required")
        if product.get('calories') is None:
            raise HTTPException(status_code=400, detail="Calories are required")
        
        product_data = {
            "name": product['name'],
            "calories": int(product.get('calories', 0)),
            "protein": float(product.get('protein', 0)),
            "fat": float(product.get('fat', 0)),
            "carbs": float(product.get('carbs', 0)),
            "created_at": get_now_poland().isoformat()
        }
        
        # Додаємо в таблицю food_products
        result = await asyncio.to_thread(
            lambda: supabase.table('food_products')
            .insert(product_data)
            .execute()
        )
        
        return {"status": "success", "data": result.data}
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error adding custom product: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/search_food")
async def search_food(query: str = Query(..., min_length=1)):
    # 1. Локальний пошук
    async def search_local():
        try:
            res = await asyncio.to_thread(
                lambda: supabase.table('food_products')
                .select('*')
                .ilike('name', f'%{query}%')
                .limit(5)
                .execute()
            )
            results = []
            for item in res.data:
                item['source'] = 'local'
                results.append(item)
            return results
        except Exception as e:
            print(f"Local DB Error: {e}")
            return []

    # 2. Глобальний пошук
    async def search_global():
        url = "https://world.openfoodfacts.org/cgi/search.pl"
        params = {
            "search_terms": query,
            "search_simple": 1,
            "action": "process",
            "json": 1,
            "page_size": 10,
            "fields": "product_name,product_name_uk,product_name_pl,nutriments,brands"
        }
        
        async with httpx.AsyncClient() as client:
            try:
                resp = await client.get(url, params=params, timeout=6.0)
                if resp.status_code != 200: return []

                data = resp.json()
                results = []
                for p in data.get('products', []):
                    name = p.get('product_name_uk') or p.get('product_name_pl') or p.get('product_name')
                    if not name: continue
                    nutri = p.get('nutriments', {})
                    cal = nutri.get('energy-kcal_100g', 0)
                    if not cal and name.lower() not in ['water', 'вода', 'woda']: continue

                    brands = p.get('brands', '')
                    full_name = f"{name} ({brands})".strip() if brands else name
                    
                    results.append({
                        "name": full_name,
                        "calories": int(cal),
                        "protein": round(float(nutri.get('proteins_100g', 0) or 0), 1),
                        "fat": round(float(nutri.get('fat_100g', 0) or 0), 1),
                        "carbs": round(float(nutri.get('carbohydrates_100g', 0) or 0), 1),
                        "source": "global"
                    })
                return results
            except httpx.ReadTimeout:
                print(f"⚠️ OpenFoodFacts TimeOut")
                return []
            except Exception as e:
                print(f"Global Search Error: {e}")
                return []

    local_results, global_results = await asyncio.gather(search_local(), search_global())
    return local_results + global_results

@router.post("/add_vitamin")
async def add_vitamin(data: VitaminSchema, service: NutritionService = Depends(get_nutrition_service)):
    """
    Зберігає налаштування прийому вітамінів.
    """
    if is_invalid_user(data.user_id):
        raise HTTPException(status_code=400, detail="Invalid User ID")
    
    try:
        vitamin_entry = data.dict() 
        service.meal_repo.add_vitamin(vitamin_entry)
        return {"status": "success", "message": "Вітамін успішно додано"}
    
    except Exception as e:
        print(f"Server Error adding vitamin: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/vitamins/{user_id}")
async def get_vitamins(user_id: str, service: NutritionService = Depends(get_nutrition_service)):
    try:
        response = service.meal_repo.get_user_vitamins(user_id)
        return response.data if response and response.data else []
    except Exception as e:
        print(f"⚠️ Error fetching vitamins (returning empty): {e}")
        # Повертаємо порожній масив замість помилки щоб не крашити frontend
        return []

@router.delete("/vitamins/{vitamin_id}")
async def delete_vitamin(vitamin_id: str, service: NutritionService = Depends(get_nutrition_service)):
    try:
        service.meal_repo.delete_vitamin(vitamin_id)
        return {"status": "success", "message": "Вітамін видалено"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))