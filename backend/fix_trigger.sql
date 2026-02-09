
-- Fix calculate_target_calories trigger to use 'age' instead of 'dob'
CREATE OR REPLACE FUNCTION calculate_target_calories()
RETURNS TRIGGER AS $$
BEGIN
  -- Harris-Benedict BMR Formula
  -- Using NEW.age instead of NEW.dob
  IF NEW.gender = 'male' THEN
      NEW.target_calories := (88.36 + (13.4 * NEW.weight) + (4.8 * NEW.height) - (5.7 * NEW.age)) * NEW.activity_level;
  ELSE
      NEW.target_calories := (447.6 + (9.2 * NEW.weight) + (3.1 * NEW.height) - (4.3 * NEW.age)) * NEW.activity_level;
  END IF;

  -- Goal Adjustment
  IF NEW.goal = 'lose' THEN
      NEW.target_calories := NEW.target_calories - 500;
  ELSIF NEW.goal = 'gain' THEN
      NEW.target_calories := NEW.target_calories + 500;
  END IF;

  -- Macro Split (30% P / 30% F / 40% C)
  -- Calories -> Grams conversion: Protein/Carbs /4, Fat /9
  NEW.target_protein := (NEW.target_calories * 0.30) / 4;
  NEW.target_fat := (NEW.target_calories * 0.30) / 9;
  NEW.target_carbs := (NEW.target_calories * 0.40) / 4;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

