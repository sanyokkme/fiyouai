from supabase import Client
from rich.console import Console

console = Console()

class ResponseWrapper:
    def __init__(self, data):
        self.data = data

class UserRepository:
    def __init__(self, client: Client):
        self.db = client
        self.profile_fields = ['id', 'name', 'email', 'avatar_url', 'created_at']

    def get_profile(self, user_id: str):
        try:
            # Fetch identity data
            p_res = self.db.table("user_profiles").select("*").eq("id", user_id).single().execute()
            if not p_res.data:
                console.print(f"[bold red]PROFILE[/] -> User not found: {user_id}")
                return p_res # Return empty/error as is
                
            # Fetch nutrition data
            n_res = self.db.table("user_nutrition").select("*").eq("user_id", user_id).single().execute()
            n_data = n_res.data if n_res and n_res.data else {}
            
            # Merge (nutrition data overrides profile keys if collision, though keys should be distinct)
            merged = {**p_res.data, **n_data}
            
            if 'user_id' in n_data:
                merged['id'] = n_data['user_id']
            
            return ResponseWrapper(merged)
        except Exception as e:
            console.print(f"   ┗━ [red]Repo Get Error: {e}[/]")
            return ResponseWrapper(None)

    def create_profile(self, profile_data: dict):
        console.print(f"[bold green]CREATE PROFILE[/] -> User: {profile_data.get('id')}")
        # Split data
        p_data = {k: v for k, v in profile_data.items() if k in self.profile_fields}
        # Nutrition data is everything else
        n_data = {k: v for k, v in profile_data.items() if k not in self.profile_fields}
        
        # Ensure ID alignment
        if 'id' in profile_data:
            p_data['id'] = profile_data['id']
            n_data['user_id'] = profile_data['id']
            
        try:
            res1 = self.db.table("user_profiles").insert(p_data).execute()
            # If creating profile, nutrition might be empty or full. 
            # Even if empty, create a row? Yes, to avoid loose ends.
            if not n_data:
                n_data['user_id'] = profile_data.get('id')
            
            # Remove 'id' from n_data if it crept in (it shouldn't if not in fields list, 
            # but profile_data['id'] is surely in profile_fields)
            if 'id' in n_data: del n_data['id'] 
                
            self.db.table("user_nutrition").insert(n_data).execute()
            return res1
        except Exception as e:
            console.print(f"   ┗━ [red]Repo Create Error: {e}[/]")
            raise e

    def update_profile(self, user_id: str, data: dict):
        """Оновлює профіль і повертає результат"""
        console.print(f"[bold yellow]UPDATE PROFILE[/] -> User: {user_id}")
        
        p_update = {k: v for k, v in data.items() if k in self.profile_fields}
        n_update = {k: v for k, v in data.items() if k not in self.profile_fields}
        
        res = None
        try:
            if p_update:
                res = self.db.table("user_profiles").update(p_update).eq("id", user_id).execute()
            
            if n_update:
                # Update nutrition table
                # Check if record exists first? Or upsert?
                # Update is safer if we assume creation happened at registration.
                self.db.table("user_nutrition").update(n_update).eq("user_id", user_id).execute()
                
            # If we only updated nutrition, res might be None (if p_update was empty).
            # Return something meaningful.
            return res if res else ResponseWrapper(data) 
        except Exception as e:
             console.print(f"   ┗━ [red]Repo Update Error: {e}[/]")
             raise e
        
    def upsert_profile(self, data: dict):
         # Not used much, but let's implement similar logic or warn
         # For simplicity, treat as create
         return self.create_profile(data)
    
    def update_user_profile(self, user_id: str, data: dict):
        return self.update_profile(user_id, data)