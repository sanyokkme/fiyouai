from repositories.meal_repo import MealRepository
from repositories.user_repo import UserRepository
from utils import clean_to_int, clean_to_float, get_now_poland
from datetime import timedelta
from rich.console import Console

console = Console()

class NutritionService:
    def __init__(self, meal_repo: MealRepository, user_repo: UserRepository):
        self.meal_repo = meal_repo
        self.user_repo = user_repo

    def calculate_bmr_tdee(self, weight: float, height: float, age: int, gender: str, activity_level: str) -> float:
        """Розрахунок базового метаболізму та TDEE."""
        # Mifflin-St Jeor Formula
        bmr = (10 * weight) + (6.25 * height) - (5 * age)
        bmr = (bmr + 5) if gender == "Чоловік" else (bmr - 161)
        
        activity_map = {
            "Сидячий": 1.2, 
            "Легка активність": 1.375, 
            "Середня активність": 1.55, 
            "Висока активність": 1.725
        }
        # Якщо activity_level прийде null або невідомий, беремо 1.2
        multiplier = activity_map.get(activity_level, 1.2)
        return bmr * multiplier

    def get_target_calories(self, tdee: float, goal: str) -> int:
        """Коригує TDEE залежно від цілі (схуднення/набір)."""
        if not goal:
            return int(tdee)
            
        goal_lower = goal.lower()
        if "lose" in goal_lower or "скинути" in goal_lower or "схуднення" in goal_lower:
            return int(tdee - 500)
        elif "gain" in goal_lower or "набрати" in goal_lower:
            return int(tdee + 500)
        
        return int(tdee)

    def calculate_macros(self, calories: int):
        """Розрахунок БЖВ (30/30/40)."""
        return {
            "protein": int((calories * 0.3) / 4),
            "fat": int((calories * 0.3) / 9),
            "carbs": int((calories * 0.4) / 4)
        }

    def get_daily_status(self, user_id: str):
        """Отримує повну статистику за сьогодні."""
        console.print(f"[bold cyan]STATUS[/] -> Fetching daily summary for: [white]{user_id}[/]")
        
        today = get_now_poland().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
        
        prof_response = self.user_repo.get_profile(user_id)
        prof = prof_response.data if prof_response else None
        
        if not prof: 
            console.print(f"   ┗━ [red]Profile not found![/]")
            return {"error": "Profile not found"}

        meals = self.meal_repo.get_meals_from_date(user_id, today).data or []
        water = self.meal_repo.get_water_logs(user_id, today).data or []
        
        console.print(f"   ┗━ [dim]Meals today:[/dim] {len(meals)} | [dim]Water logs:[/dim] {len(water)}")

        target = max(1200, int(prof.get("daily_calories_target", 2000)))
        eaten = sum(clean_to_int(m.get('calories', 0)) for m in meals)

        try:
            stories_response = self.meal_repo.get_stories()
            stories = stories_response.data if stories_response.data else []
        except Exception as e:
            console.print(f"   ┗━ [red]Error fetching stories: {e}[/]")
            stories = []
        
        macros = self.calculate_macros(target)
        
        console.print(f"   ┗━ [green]Success[/] -> Eaten: {eaten}/{target} kcal")

        return {
            "user_id": user_id,
            "name": prof.get("name"),  
            "username": prof.get("username", "Користувач"), 
            "eaten": eaten, 
            "target": target, 
            "remaining": max(0, target - eaten),
            "goal": prof.get("goal"),
            "protein": sum(clean_to_float(m.get('protein')) for m in meals),
            "fat": sum(clean_to_float(m.get('fat')) for m in meals),
            "carbs": sum(clean_to_float(m.get('carbs')) for m in meals),
            "water": sum(w['amount'] for w in water), 
            "water_target": int(prof.get("weight", 70) * 35),
            "stories": stories,
            "weight": prof.get("weight"),
            "avatar_url": prof.get("avatar_url"),
            "target_p": macros["protein"], 
            "target_f": macros["fat"], 
            "target_c": macros["carbs"]
        }

    def get_weekly_analytics(self, user_id: str):
        """Повертає статистику всіх метрик за останні 7 днів."""
        week_ago = (get_now_poland().replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=7)).isoformat()
        
        console.print(f"[bold cyan]ANALYTICS[/] -> Fetching for user: [white]{user_id}[/]")
        console.print(f"   ┗━ [dim]Date range start:[/dim] {week_ago}")
        
        meals_res = self.meal_repo.get_meals_from_date(user_id, week_ago)
        water_res = self.meal_repo.get_water_logs(user_id, week_ago)
        
        if meals_res.data:
            console.print(f"   ┗━ [green]Found {len(meals_res.data)} meals[/]")
        else:
            console.print(f"   ┗━ [yellow]NO MEALS FOUND[/] via query")
            console.print(f"      [dim]Query: user_id={user_id}, created_at >= {week_ago}[/]")
            
            # --- DEBUG CHECK: Check if ANY meals exist for this user ---
            try:
                all_meals = self.meal_repo.supabase.table("meal_history").select("count").eq("user_id", user_id).execute()
                count = all_meals.data[0]['count'] if all_meals.data else 0
                console.print(f"      [dim]Total meals (all time): {count}[/]")
            except Exception as e:
                console.print(f"      [red]Check failed: {e}[/]")
            # -----------------------------------------------------------

        meals_data = meals_res.data or []
        water_data = water_res.data or []
        
        # Агрегація по днях
        stats = {}
        from utils import safe_parse_datetime 
        
        # Обробка страв (калорії, білки, жири, вуглеводи)
        for entry in meals_data:
            dt = safe_parse_datetime(entry['created_at'])
            day = dt.date().isoformat()
            
            if day not in stats:
                stats[day] = {
                    "calories": 0,
                    "protein": 0,
                    "fat": 0,
                    "carbs": 0,
                    "water": 0
                }
            
            stats[day]["calories"] += clean_to_int(entry.get('calories', 0))
            stats[day]["protein"] += clean_to_float(entry.get('protein', 0))
            stats[day]["fat"] += clean_to_float(entry.get('fat', 0))
            stats[day]["carbs"] += clean_to_float(entry.get('carbs', 0))
        
        # Обробка води
        for entry in water_data:
            dt = safe_parse_datetime(entry['created_at'])
            day = dt.date().isoformat()
            
            if day not in stats:
                stats[day] = {
                    "calories": 0,
                    "protein": 0,
                    "fat": 0,
                    "carbs": 0,
                    "water": 0
                }
            
            stats[day]["water"] += entry.get('amount', 0)
        
        # Форматуємо результат
        result = []
        for day, metrics in sorted(stats.items()):
            result.append({
                "day": day,
                "calories": metrics["calories"],
                "protein": round(metrics["protein"], 1),
                "fat": round(metrics["fat"], 1),
                "carbs": round(metrics["carbs"], 1),
                "water": metrics["water"]
            })
        
        return result
        
    def get_data_for_tips(self, user_id: str):
        """Збирає дані (історія + профіль) для генерації порад."""
        console.print(f"[bold cyan]AI TIPS[/] -> Fetching context for: [white]{user_id}[/]")
        
        week_ago = (get_now_poland().replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=7)).isoformat()
        
        history = self.meal_repo.get_meals_from_date(user_id, week_ago).data or []
        profile = self.user_repo.get_profile(user_id).data or {}
        
        console.print(f"   ┗━ [green]Found[/] {len(history)} recent meals")
        
        return history, profile