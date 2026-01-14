-- Add trigger to send push notifications when a notification is created
-- This calls the Edge Function to send the actual push notification

-- Create function to invoke Edge Function
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
  -- Note: pg_net must be enabled in Supabase dashboard
  PERFORM net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
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
DROP TRIGGER IF EXISTS on_notification_created_send_push ON public.notifications;
CREATE TRIGGER on_notification_created_send_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_push_notification();

-- Add comment explaining setup requirements
COMMENT ON FUNCTION public.notify_push_notification() IS 
'Triggers push notification via Edge Function. Requires:
1. pg_net extension enabled
2. Edge Function "send-push-notification" deployed
3. app.settings.supabase_url and app.settings.service_role_key configured
4. APNs credentials set in Edge Function environment variables';
