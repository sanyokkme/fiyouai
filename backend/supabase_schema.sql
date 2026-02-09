-- Add columns for Target Weight and Estimation to the user_profiles table

ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS target_weight NUMERIC,
ADD COLUMN IF NOT EXISTS weekly_change_goal NUMERIC, -- e.g., -0.5 for losing 0.5kg/week
ADD COLUMN IF NOT EXISTS estimated_end_date TIMESTAMP WITH TIME ZONE;

-- Optional: Comment on columns
COMMENT ON COLUMN public.user_profiles.target_weight IS 'Target weight in kg';
COMMENT ON COLUMN public.user_profiles.weekly_change_goal IS 'Weekly weight change goal in kg (negative for loss, positive for gain)';
COMMENT ON COLUMN public.user_profiles.estimated_end_date IS 'Estimated date to reach the target weight';
