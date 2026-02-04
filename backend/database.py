from supabase import create_client, Client
from config import settings

# Створюємо клієнт із правами Service Role (Admin)
supabase: Client = create_client(
    settings.SUPABASE_URL, 
    settings.SUPABASE_SERVICE_ROLE_KEY
)

url = settings.SUPABASE_URL
key = settings.SUPABASE_SERVICE_ROLE_KEY