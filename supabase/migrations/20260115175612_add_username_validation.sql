-- Add username format validation to profiles table
-- Only allows lowercase letters, numbers, and underscores

-- Add a CHECK constraint for username format
ALTER TABLE public.profiles
ADD CONSTRAINT username_format_check
CHECK (username ~ '^[a-z0-9_]+$');

-- Add a trigger to automatically sanitize usernames on insert/update
CREATE OR REPLACE FUNCTION sanitize_username()
RETURNS TRIGGER AS $$
BEGIN
    -- Convert to lowercase and remove invalid characters
    NEW.username := lower(regexp_replace(NEW.username, '[^a-z0-9_]', '', 'gi'));
    
    -- Ensure username is not empty after sanitization
    IF NEW.username = '' OR NEW.username IS NULL THEN
        RAISE EXCEPTION 'Username cannot be empty';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to sanitize username before insert or update
DROP TRIGGER IF EXISTS sanitize_username_trigger ON public.profiles;
CREATE TRIGGER sanitize_username_trigger
    BEFORE INSERT OR UPDATE OF username ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION sanitize_username();

-- Add comment explaining the constraint
COMMENT ON CONSTRAINT username_format_check ON public.profiles IS 
    'Usernames must contain only lowercase letters, numbers, and underscores';
