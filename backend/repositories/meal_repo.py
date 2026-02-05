from supabase import Client

class MealRepository:
    def __init__(self, client: Client):
        self.supabase = client

    def get_meals_from_date(self, user_id: str, date_from: str):
        return self.supabase.table("meal_history").select("*").eq("user_id", user_id).gte("created_at", date_from).execute()

    def add_meal(self, meal_data: dict):
        return self.supabase.table("meal_history").insert(meal_data).execute()

    def get_water_logs(self, user_id: str, date_from: str):
        return self.supabase.table("water_logs").select("amount").eq("user_id", user_id).gte("created_at", date_from).execute()

    def add_water(self, water_data: dict):
        return self.supabase.table("water_logs").insert(water_data).execute()

    def save_recipe(self, recipe_data: dict):
        return self.supabase.table("saved_recipes").insert(recipe_data).execute()

    def get_saved_recipes(self, user_id: str):
        return self.supabase.table("saved_recipes").select("*").eq("user_id", user_id).order("created_at", desc=True).execute()

    def delete_recipe(self, recipe_id: str):
        return self.supabase.table("saved_recipes").delete().eq("id", recipe_id).execute()

    def get_stories(self):
        return self.supabase.table('app_stories').select('*').eq('is_active', True).execute()