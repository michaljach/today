-- Fix push notification trigger to use correct Supabase URL
-- The Edge Function will be invoked using the anon key which is safe since
-- the function verifies requests using its own service role key internally

-- Drop old trigger and function
DROP TRIGGER IF EXISTS on_notification_created_send_push ON public.notifications;
DROP FUNCTION IF EXISTS public.notify_push_notification();

-- Create updated function with hardcoded project URL
CREATE OR REPLACE FUNCTION public.notify_push_notification()
RETURNS TRIGGER AS $$
DECLARE
  payload jsonb;
BEGIN
  payload := jsonb_build_object(
    'recipient_id', NEW.recipient_id,
    'actor_id', NEW.actor_id,
    'type', NEW.type,
    'post_id', NEW.post_id,
    'comment_id', NEW.comment_id
  );
  
  -- Call the Edge Function via pg_net extension
  -- Using anon key - the Edge Function uses service role internally
  PERFORM net.http_post(
    url := 'https://ulgnrfmukvlagnccxlks.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_uFs_Auv4eIz5UpltXDVtJQ_bggmAkpP'
    ),
    body := payload
  );
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the insert
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on notifications table
CREATE TRIGGER on_notification_created_send_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_push_notification();
