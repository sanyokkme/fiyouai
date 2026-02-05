from repositories.meal_repo import MealRepository
from repositories.user_repo import UserRepository
from utils import clean_to_int, clean_to_float, get_now_poland
from datetime import timedelta

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
        today = get_now_poland().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
        
        prof_response = self.user_repo.get_profile(user_id)
        prof = prof_response.data if prof_response else None
        
        if not prof: return {"error": "Profile not found"}

        meals = self.meal_repo.get_meals_from_date(user_id, today).data or []
        water = self.meal_repo.get_water_logs(user_id, today).data or []

        target = max(1200, int(prof.get("daily_calories_target", 2000)))
        eaten = sum(clean_to_int(m.get('calories', 0)) for m in meals)

        try:
            stories_response = self.meal_repo.get_stories()
            stories = stories_response.data if stories_response.data else []
        except Exception as e:
            print(f"Error fetching stories: {e}")
            stories = []
        
        macros = self.calculate_macros(target)

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
            "avatar_url": prof.get("avatar_url"),
            "target_p": macros["protein"], 
            "target_f": macros["fat"], 
            "target_c": macros["carbs"]
        }

    def get_weekly_analytics(self, user_id: str):
        """Повертає статистику калорій за останні 7 днів."""
        week_ago = (get_now_poland().replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=7)).isoformat()
        
        res = self.meal_repo.get_meals_from_date(user_id, week_ago)
        data = res.data or []
        
        stats = {}
        from utils import safe_parse_datetime 
        
        for entry in data:
            dt = safe_parse_datetime(entry['created_at'])
            day = dt.date().isoformat()
            stats[day] = stats.get(day, 0) + clean_to_int(entry['calories'])
            
        return [{"day": k, "value": v} for k, v in sorted(stats.items())]
        
    def get_data_for_tips(self, user_id: str):
        """Збирає дані (історія + профіль) для генерації порад."""
        week_ago = (get_now_poland().replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=7)).isoformat()
        
        history = self.meal_repo.get_meals_from_date(user_id, week_ago).data or []
        profile = self.user_repo.get_profile(user_id).data or {}
        
        return history, profile