-- Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- The user who receives the notification
    recipient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    -- The user who triggered the notification (e.g., who liked/followed)
    actor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    -- Type of notification: 'like', 'follow', 'comment'
    type TEXT NOT NULL CHECK (type IN ('like', 'follow', 'comment')),
    -- Reference to the related entity (post_id for likes/comments, null for follows)
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    -- For comments, store the comment id
    comment_id UUID,
    -- Read status
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Don't notify yourself
    CHECK (recipient_id != actor_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_id ON public.notifications(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread ON public.notifications(recipient_id, is_read) WHERE is_read = FALSE;

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can only view their own notifications
CREATE POLICY "Users can view own notifications"
    ON public.notifications FOR SELECT
    USING (auth.uid() = recipient_id);

-- System (triggers) can insert notifications - we'll use a service role for this
-- But we also allow inserts where actor is the current user
CREATE POLICY "Users can create notifications as actor"
    ON public.notifications FOR INSERT
    WITH CHECK (auth.uid() = actor_id);

-- Users can update (mark as read) their own notifications
CREATE POLICY "Users can update own notifications"
    ON public.notifications FOR UPDATE
    USING (auth.uid() = recipient_id)
    WITH CHECK (auth.uid() = recipient_id);

-- Users can delete their own notifications
CREATE POLICY "Users can delete own notifications"
    ON public.notifications FOR DELETE
    USING (auth.uid() = recipient_id);

-- Enable realtime for the notifications table
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- Create function to notify on new follow
CREATE OR REPLACE FUNCTION notify_on_follow()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert notification for the followed user
    INSERT INTO public.notifications (recipient_id, actor_id, type)
    VALUES (NEW.following_id, NEW.follower_id, 'follow')
    ON CONFLICT DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for follows
DROP TRIGGER IF EXISTS on_follow_notify ON public.follows;
CREATE TRIGGER on_follow_notify
    AFTER INSERT ON public.follows
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_follow();

-- Create function to notify on new like
CREATE OR REPLACE FUNCTION notify_on_like()
RETURNS TRIGGER AS $$
DECLARE
    post_owner_id UUID;
BEGIN
    -- Get the post owner
    SELECT user_id INTO post_owner_id FROM public.posts WHERE id = NEW.post_id;
    
    -- Don't notify if liking own post
    IF post_owner_id IS NOT NULL AND post_owner_id != NEW.user_id THEN
        INSERT INTO public.notifications (recipient_id, actor_id, type, post_id)
        VALUES (post_owner_id, NEW.user_id, 'like', NEW.post_id)
        ON CONFLICT DO NOTHING;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for likes
DROP TRIGGER IF EXISTS on_like_notify ON public.likes;
CREATE TRIGGER on_like_notify
    AFTER INSERT ON public.likes
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_like();

-- Create function to notify on new comment
CREATE OR REPLACE FUNCTION notify_on_comment()
RETURNS TRIGGER AS $$
DECLARE
    post_owner_id UUID;
BEGIN
    -- Get the post owner
    SELECT user_id INTO post_owner_id FROM public.posts WHERE id = NEW.post_id;
    
    -- Don't notify if commenting on own post
    IF post_owner_id IS NOT NULL AND post_owner_id != NEW.user_id THEN
        INSERT INTO public.notifications (recipient_id, actor_id, type, post_id, comment_id)
        VALUES (post_owner_id, NEW.user_id, 'comment', NEW.post_id, NEW.id)
        ON CONFLICT DO NOTHING;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for comments
DROP TRIGGER IF EXISTS on_comment_notify ON public.comments;
CREATE TRIGGER on_comment_notify
    AFTER INSERT ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_comment();
