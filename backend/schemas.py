from pydantic import BaseModel, Field, field_validator
from typing import Optional, List, Union, Dict, Any

# --- Response Models ---
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

# --- Request Models ---

class UserProfileSchema(BaseModel):
    name: Optional[str] = None
    dob: Optional[str] = None
    weight: float = 70.0
    height: float = 170.0
    gender: str = "Чоловік"
    activity: str = "Сидячий"
    goal: str = "Підтримка ваги"

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
    field: str
    value: Union[str, int, float]

class ProfileSetupSchema(BaseModel):
    id: str
    name: str
    weight: int
    height: int
    age: int
    gender: str
    goal: str

class WaterLogSchema(BaseModel):
    user_id: str
    amount: int = 250
    created_at: Optional[str] = None

class ManualMealSchema(BaseModel):
    user_id: str
    meal_name: str = "Ручне введення"
    # Дозволяємо різні формати на вході
    calories: Union[int, float, str] 
    protein: Union[int, float, str] = 0
    fat: Union[int, float, str] = 0
    carbs: Union[int, float, str] = 0
    image_url: Optional[str] = None
    created_at: Optional[str] = None

    # mode='before' означає: спершу виконай цю функцію, а потім перевіряй типи.
    # Це дозволяє прийняти "250.5" (рядок або float) і перетворити на 250 (int).
    @field_validator('calories', mode='before')
    def round_calories(cls, v):
        if v is None:
            return 0
        try:
            return int(float(v))
        except (ValueError, TypeError):
            return 0

    # Додамо валідатори для макронутрієнтів, щоб вони завжди були float
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

    # Тут теж корисно додати валідатор, щоб чистити дані перед збереженням
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