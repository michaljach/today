-- Remove exposed token from trigger - Edge Function uses --no-verify-jwt

DROP TRIGGER IF EXISTS on_notification_created_send_push ON public.notifications;
DROP FUNCTION IF EXISTS public.notify_push_notification();

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
  -- No auth needed since function is deployed with --no-verify-jwt
  PERFORM net.http_post(
    url := 'https://ulgnrfmukvlagnccxlks.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := payload
  );
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_notification_created_send_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_push_notification();
