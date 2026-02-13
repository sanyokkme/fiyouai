-- Add account_type column to user_profiles table
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS account_type TEXT DEFAULT 'free';

-- Update existing users to have 'free' account type if null
UPDATE user_profiles 
SET account_type = 'free' 
WHERE account_type IS NULL;
