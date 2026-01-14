-- Add policy to allow service role to read all push tokens
-- This is needed for the Edge Function to send notifications to recipients

-- Allow service role (used by Edge Functions) to read all tokens
CREATE POLICY "Service role can read all tokens" ON public.push_tokens
    FOR SELECT USING (true);
