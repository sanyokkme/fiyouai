import base64
import json
import io
import os
import logging
from openai import OpenAI
from PIL import Image

# Налаштуємо логування, щоб бачити помилки в консолі
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AIService:
    def __init__(self):
        self.client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

    def get_calories_from_image(self, image: Image.Image):
        """Аналізує зображення страви та повертає JSON з калоріями та БЖВ."""
        try:
            # 1. Підготовка зображення
            buffer = io.BytesIO()
            image.save(buffer, format="JPEG")
            base64_image = base64.b64encode(buffer.getvalue()).decode("utf-8")

            # 2. Запит до GPT-4o
            response = self.client.chat.completions.create(
                model="gpt-4o",
                response_format={"type": "json_object"},
                messages=[
                    {
                        "role": "system",
                        "content": """Ви — професійний дієтолог. Проаналізуйте фото їжі.
                        ОБОВ'ЯЗКОВО розрахуйте калорійність на основі БЖВ: (білки * 4) + (вуглеводи * 4) + (жири * 9).
                        Поверніть JSON:
                        {
                            "meal_name": "конкретна назва страви",
                            "calories": ціле число (НЕ 0),
                            "protein": число грам білків,
                            "fat": число грам жирів,
                            "carbs": число грам вуглеводів
                        }"""
                    },
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": "Оціни цю страву. Дай детальну оцінку Ккал та БЖВ."},
                            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}}
                        ]
                    }
                ]
            )

            # 3. Парсинг відповіді
            content = response.choices[0].message.content
            if not content:
                raise ValueError("Отримано порожню відповідь від OpenAI")
            
            result = json.loads(content)
            
            # 4. ЗАПОБІЖНИК: Перерахунок калорій, якщо GPT помилився або повернув 0
            p = float(result.get("protein", 0))
            f = float(result.get("fat", 0))
            c = float(result.get("carbs", 0))
            
            current_calories = result.get("calories", 0)
            
            # Якщо калорії 0, рахуємо вручну
            if current_calories == 0:
                calculated_cal = int((p * 4) + (c * 4) + (f * 9))
                result["calories"] = calculated_cal
                logger.info(f"DEBUG: Калорії перераховані вручну: {calculated_cal}")

            # Тут ми НЕ генеруємо нове зображення DALL-E, бо у нас вже є фото користувача.
            # Якщо вам все ж потрібна генерація, скажіть, я додам цей код коректно.
            
            return result

        except Exception as e:
            logger.error(f"Error analyzing food image: {e}")
            # Повертаємо безпечну структуру, щоб фронтенд не впав
            return {
                "meal_name": "Не вдалося розпізнати",
                "calories": 0,
                "protein": 0, "fat": 0, "carbs": 0
            }

    def generate_personalized_recipe(self, remaining_cal: int, preferences: list, goal: str):
        """Генерує рецепт та зображення."""
        recipe_prompt = f"""
        Користувач має {remaining_cal} ккал залишку. Його ціль: {goal}. Вподобання: {', '.join(preferences)}.
        Запропонуй рецепт. ПИШИ ВИКЛЮЧНО УКРАЇНСЬКОЮ МОВОЮ.
        
        Поверни ТІЛЬКИ JSON:
        {{
            "title": "назва страви",
            "calories": ціле число,
            "protein": число (білки),
            "fat": число (жири),
            "carbs": число (вуглеводи),
            "time": "наприклад, 20 хв",
            "ingredients": "список інгредієнтів одним текстом",
            "instructions": "кроки приготування одним текстом"
        }}
        """
        
        try:
            # 1. Генерація тексту рецепту
            recipe_res = self.client.chat.completions.create(
                model="gpt-4o",
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": "Ви — шеф-кухар та нутріціолог. Видавайте дані строго у форматі JSON українською мовою."},
                    {"role": "user", "content": recipe_prompt}
                ]
            )
            recipe_data = json.loads(recipe_res.choices[0].message.content)
            
            # Запобіжник defaults
            recipe_data.setdefault("title", "Смачна страва")
            recipe_data.setdefault("protein", 0)
            recipe_data.setdefault("fat", 0)
            recipe_data.setdefault("carbs", 0)
            
            # 2. Генерація зображення (DALL-E 3)
            try:
                dish_title = recipe_data.get("title", "Healthy meal")
                # Оптимізація: quality="standard" дешевше і швидше, ніж HD
                image_res = self.client.images.generate(
                    model="dall-e-3",
                    prompt=f"Professional food photography of {dish_title}, soft lighting, top down view",
                    size="1024x1024",
                    quality="standard", 
                    n=1
                )
                recipe_data["image_url"] = image_res.data[0].url
            except Exception as e:
                logger.error(f"DALL-E error: {e}")
                recipe_data["image_url"] = None
            
            return recipe_data

        except Exception as e:
            logger.error(f"General Recipe AI Error: {e}")
            return {
                "title": "Помилка генерації",
                "calories": 0,
                "protein": 0, "fat": 0, "carbs": 0,
                "ingredients": "Не вдалося отримати дані",
                "instructions": "Спробуйте ще раз пізніше.",
                "image_url": None
            }

    def get_weekly_insights(self, history: list, target: int, goal: str):
        """Аналізує тиждень та повертає поради."""
        # Перетворюємо history (якщо це об'єкти БД) у простий текст або dict, щоб не було помилок серіалізації
        history_str = str(history) 

        prompt = f"""
        Ти — експерт-нутріціолог. ПИШИ ТІЛЬКИ УКРАЇНСЬКОЮ МОВОЮ.
        Проаналізуй дані користувача за тиждень: {history_str}.
        Денна норма: {target} ккал. Ціль: {goal}.
        
        Напиши 3 короткі, мотиваційні поради. Поверни ТІЛЬКИ JSON:
        {{
            "summary": "короткий висновок одним реченням",
            "tips": [
                {{"title": "заголовок", "text": "порада"}}
            ]
        }}
        """
        try:
            response = self.client.chat.completions.create(
                model="gpt-4o",
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": "Ти персональний дієтолог."},
                    {"role": "user", "content": prompt}
                ]
            )
            return json.loads(response.choices[0].message.content)
        except Exception as e:
            logger.error(f"Weekly insights error: {e}")
            return {
                "summary": "Не вдалося проаналізувати дані.",
                "tips": []
            }

# Експортуємо
ai_service_instance = AIService()