from supabase import Client

class UserRepository:
    def __init__(self, client: Client):
        self.db = client

    def get_profile(self, user_id: str):
        return self.db.table("user_profiles").select("*").eq("id", user_id).single().execute()

    def create_profile(self, profile_data: dict):
        return self.db.table("user_profiles").insert(profile_data).execute()

    def update_profile(self, user_id: str, data: dict):
        """Оновлює профіль і повертає результат"""
        return self.db.table("user_profiles").update(data).eq("id", user_id).execute()
        
    def upsert_profile(self, data: dict):
        return self.db.table("user_profiles").upsert(data).execute()
    
    def update_user_profile(self, user_id: str, data: dict):
        """Метод, який використовується для оновлення ваги"""
        return self.db.table("user_profiles").update(data).eq("id", user_id).execute()