from fastapi import APIRouter, HTTPException, Depends, Query
from schemas import WaterLogSchema, ManualMealSchema, SaveRecipeSchema, AddFromRecipeSchema
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

# --- ОСЬ ЦЕЙ ЕНДПОІНТ БУВ ВІДСУТНІЙ ---
@router.post("/add_from_recipe")
async def add_from_recipe(data: AddFromRecipeSchema, service: NutritionService = Depends(get_nutrition_service)):
    if is_invalid_user(data.user_id): raise HTTPException(status_code=400, detail="Invalid User")
    
    r = data.recipe
    
    # Створюємо запис для історії
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
    """
    Додає продукт, вибраний через пошук або введений вручну.
    """
    try:
        # Формуємо словник для запису в БД
        # Важливо: імена ключів мають збігатися з колонками в таблиці meal_history
        meal_data = {
            "user_id": meal.user_id,
            "meal_name": meal.meal_name, # Або просто "name", перевір як в БД
            "calories": meal.calories,
            "protein": meal.protein,
            "fat": meal.fat,
            "carbs": meal.carbs,
            "created_at": meal.created_at,
            # Якщо є картинка - додаємо, якщо ні - ставимо заглушку або None
            "image_url": meal.image_url 
        }

        result = service.meal_repo.add_meal(meal_data)

        return {"status": "success", "data": result.data}

    except Exception as e:
        print(f"Error adding manual meal: {e}")
        raise HTTPException(status_code=500, detail=str(e))       

@router.get("/search_food")
async def search_food(query: str = Query(..., min_length=1)):
    """
    Асинхронний гібридний пошук.
    Запускає пошук локально і глобально паралельно.
    """
    
    # --- 1. Функція для локального пошуку (Supabase) ---
    async def search_local():
        try:
            # Supabase клієнт синхронний, тому загортаємо в потік, щоб не блокувати
            # Якщо у тебе async клієнт supabase, to_thread не потрібен
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

    # --- 2. Функція для глобального пошуку (OpenFoodFacts) ---
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
        
        # Використовуємо AsyncClient замість requests!
        async with httpx.AsyncClient() as client:
            try:
                # Таймаут збільшено до 6 секунд
                resp = await client.get(url, params=params, timeout=6.0)
                
                if resp.status_code != 200:
                    return []

                data = resp.json()
                results = []
                
                for p in data.get('products', []):
                    name = p.get('product_name_uk') or p.get('product_name_pl') or p.get('product_name')
                    if not name: continue
                    
                    nutri = p.get('nutriments', {})
                    cal = nutri.get('energy-kcal_100g', 0)
                    
                    # Фільтр сміття (без калорій)
                    if not cal and name.lower() not in ['water', 'вода', 'woda']:
                        continue

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
                print(f"⚠️ OpenFoodFacts TimeOut (Skipping global search)")
                return []
            except Exception as e:
                print(f"Global Search Error: {e}")
                return []

    # --- 3. ЗАПУСКАЄМО ОБИДВА ПОШУКИ ОДНОЧАСНО ---
    # Це магія asyncio.gather - чекаємо завершення обох
    local_results, global_results = await asyncio.gather(search_local(), search_global())
    
    # Об'єднуємо: спочатку локальні (швидкі/надійні), потім глобальні
    return local_results + global_results