-- =========================================================
-- HENA NOTIFICATIONS FOUNDATION
-- =========================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  recipient_user_id uuid NOT NULL
    REFERENCES public.profiles(id) ON DELETE CASCADE,

  title text NOT NULL,
  body text NOT NULL,

  type text NOT NULL DEFAULT 'system',

  data jsonb NOT NULL DEFAULT '{}'::jsonb,

  is_read boolean NOT NULL DEFAULT false,
  read_at timestamptz NULL,

  created_by uuid NULL
    REFERENCES public.profiles(id) ON DELETE SET NULL,

  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created
  ON public.notifications(recipient_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread
  ON public.notifications(recipient_user_id, is_read, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_select_own
  ON public.notifications;

CREATE POLICY notifications_select_own
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (recipient_user_id = auth.uid());

DROP POLICY IF EXISTS notifications_update_own
  ON public.notifications;

CREATE POLICY notifications_update_own
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (recipient_user_id = auth.uid())
  WITH CHECK (recipient_user_id = auth.uid());

DROP POLICY IF EXISTS notifications_insert_admin
  ON public.notifications;

CREATE POLICY notifications_insert_admin
  ON public.notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_admin()
  );

GRANT SELECT, UPDATE ON TABLE public.notifications TO authenticated;
GRANT INSERT ON TABLE public.notifications TO authenticated;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.notifications;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END
$$;
