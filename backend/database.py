from supabase import create_client, Client
from config import settings

supabase: Client = create_client(
    settings.SUPABASE_URL, 
    settings.SUPABASE_SERVICE_ROLE_KEY
)

url = settings.SUPABASE_URL
key = settings.SUPABASE_SERVICE_ROLE_KEY