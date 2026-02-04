from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Supabase
    SUPABASE_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str
    SUPABASE_JWT_SECRET: str
    
    # OpenAI
    OPENAI_API_KEY: str
    
    # Admin Panel
    ADMIN_USERNAME: str = "admin"
    ADMIN_PASSWORD: str = "admin"

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()