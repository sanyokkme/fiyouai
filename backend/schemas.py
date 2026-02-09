from pydantic import BaseModel, Field, field_validator
from typing import Optional, List, Union, Dict, Any

# Response Models
class DailyStatusResponse(BaseModel):
    user_id: str
    name: Optional[str] = None
    username: Optional[str] = None
    eaten: int
    target: int
    remaining: int
    goal: Optional[str] = None
    protein: float
    fat: float
    carbs: float
    water: int
    water_target: int
    avatar_url: Optional[str] = None
    target_p: int
    target_f: int
    target_c: int

# Request Models

class UserProfileSchema(BaseModel):
    name: Optional[str] = None
    dob: Optional[str] = None
    weight: float = 70.0
    height: float = 170.0
    gender: str = "Чоловік"
    activity_level: str = "Сидячий"
    goal: str = "Підтримка ваги"
    target_weight: Optional[float] = None  # ✅ ДОДАНО
    weekly_change_goal: Optional[float] = None  # ✅ ДОДАНО e.g. -0.5
    estimated_end_date: Optional[str] = None  # ✅ ДОДАНО e.g. "2024-05-01"

class RegisterSchema(BaseModel):
    email: str
    password: str
    profile: UserProfileSchema = Field(default_factory=UserProfileSchema)

class LoginSchema(BaseModel):
    email: str
    password: str

class PasswordResetSchema(BaseModel):
    email: str

class ProfileUpdateSchema(BaseModel):
    user_id: str
    field: Optional[str] = "weight"
    value: Union[str, int, float]

class ProfileSetupSchema(BaseModel):
    id: str
    name: str
    weight: float  # Змінено з int
    height: int
    age: int
    gender: str
    goal: str
    activity_level: str  # ✅ ДОДАНО
    dob: str       # Якщо потрібно

class WaterLogSchema(BaseModel):
    user_id: str
    amount: int = 250
    created_at: Optional[str] = None

class ManualMealSchema(BaseModel):
    user_id: str
    meal_name: str = "Ручне введення"
    calories: Union[int, float, str] 
    protein: Union[int, float, str] = 0
    fat: Union[int, float, str] = 0
    carbs: Union[int, float, str] = 0
    image_url: Optional[str] = None
    created_at: Optional[str] = None

    @field_validator('calories', mode='before')
    def round_calories(cls, v):
        if v is None:
            return 0
        try:
            return int(float(v))
        except (ValueError, TypeError):
            return 0

    @field_validator('protein', 'fat', 'carbs', mode='before')
    def parse_float(cls, v):
        if v is None:
            return 0.0
        try:
            return float(v)
        except (ValueError, TypeError):
            return 0.0


class SaveRecipeSchema(BaseModel):
    user_id: str
    title: Optional[str] = None
    recipe_name: Optional[str] = None
    calories: Optional[Union[int, str, float]] = 0 
    protein: Optional[Union[float, str, int]] = 0
    fat: Optional[Union[float, str, int]] = 0
    carbs: Optional[Union[float, str, int]] = 0
    ingredients: Optional[Any] = [] 
    instructions: Optional[Any] = []
    time: Optional[str] = "20 хв"
    image_url: Optional[str] = None 

    @field_validator('calories', mode='before')
    def clean_calories(cls, v):
        if v is None: return 0
        try: return int(float(v))
        except: return 0

class AddFromRecipeSchema(BaseModel):
    user_id: str
    recipe: Dict[str, Any]

class UpdatePasswordSchema(BaseModel):
    password: str

class ChangeEmailSchema(BaseModel):
    user_id: str
    new_email: str
    password: str

class VitaminSchema(BaseModel):
    user_id: str
    name: str
    description: Optional[str] = None
    brand: Optional[str] = None
    type: str  # pill, capsule, etc.
    frequency_type: str # every_day, interval, week_days
    frequency_data: Optional[str] = None # "2" or "1,3,5"
    start_date: str # ISO format string
    duration_days: Optional[int] = None
    schedules: List[Dict[str, Any]] # [{"time": "08:00", "dose": "1 шт"}]