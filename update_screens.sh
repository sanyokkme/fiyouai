#!/bin/bash

# Скрипт для додавання імпорту AppColors та оновлення фону у файлах Flutter

# Список файлів для оновлення
FILES=(
  "flutter_app/lib/screens/all_vitamins_screen.dart"
  "flutter_app/lib/screens/recipes_screen.dart"
  "flutter_app/lib/screens/recipe_book_screen.dart"
  "flutter_app/lib/screens/camera_screen.dart"
  "flutter_app/lib/screens/food_search_screen.dart"
  "flutter_app/lib/screens/onboarding_screen.dart"
  "flutter_app/lib/screens/story_view_screen.dart"
  "flutter_app/lib/screens/tips_screen.dart"
  "flutter_app/lib/screens/welcome_screen.dart"
  "flutter_app/lib/screens/basic/login_screen.dart"
  "flutter_app/lib/screens/basic/register_screen.dart"
  "flutter_app/lib/screens/basic/confirmation_screen.dart"
  "flutter_app/lib/screens/basic/forgot_password_screen.dart"
  "flutter_app/lib/screens/basic/reset_password_screen.dart"
  "flutter_app/lib/screens/basic/splash_screen.dart"
)

echo "Оновлення файлів екранів..."

for file in "${FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "Обробка $file..."
    
    # Додаємо імпорт якщо його ще немає
    if ! grep -q "import.*app_colors.dart" "$file"; then
      # Знаходимо останній рядок з import та додаємо після нього
      if grep -q "../services/auth_service.dart" "$file"; then
        sed -i '' "/import.*auth_service.dart/a\\
import '../constants/app_colors.dart';
" "$file"
      elif grep -q "../../services/auth_service.dart" "$file"; then
        sed -i '' "/import.*auth_service.dart/a\\
import '../../constants/app_colors.dart';
" "$file"
      else
        # Додаємо після першого import
        sed -i '' "1a\\
import '../constants/app_colors.dart';
" "$file"
      fi
    fi
  else
    echo "Файл $file не знайдено"
  fi
done

echo "Готово!"
