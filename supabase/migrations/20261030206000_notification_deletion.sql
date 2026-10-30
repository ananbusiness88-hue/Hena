-- ============================================================
-- HENA - In app notification deletion
--
-- A signed in user can delete one of their own notifications or all
-- of them. The ownership check is enforced by the backend, not by the
-- application: the delete functions only ever touch rows whose
-- recipient_user_id is auth.uid(), and the table has a row level
-- security policy that allows a user to delete only their own rows.
--
-- Unrelated business records (orders, products, ...) are never
-- touched.
-- ============================================================

-- ------------------------------------------------------------
-- 1) Row Level Security for the delete policy.
-- ------------------------------------------------------------

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_delete_own" ON "public"."notifications";

CREATE POLICY "notifications_delete_own" ON "public"."notifications"
FOR DELETE TO "authenticated"
USING ("recipient_user_id" = "auth"."uid"());

-- The anonymous role must never be able to delete notifications.
REVOKE DELETE ON TABLE public.notifications FROM anon;

-- ------------------------------------------------------------
-- 2) Delete one notification of the signed in user.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.delete_notification(
  p_notification_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_deleted integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_notification_id IS NULL THEN
    RAISE EXCEPTION 'Notification id is required';
  END IF;

  DELETE FROM public.notifications n
  WHERE n.id = p_notification_id
    AND n.recipient_user_id = auth.uid();

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN v_deleted > 0;
END;
$function$;

REVOKE ALL ON FUNCTION public.delete_notification(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.delete_notification(uuid) TO authenticated;

-- ------------------------------------------------------------
-- 3) Delete every notification of the signed in user.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.delete_all_notifications()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_deleted integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  DELETE FROM public.notifications n
  WHERE n.recipient_user_id = auth.uid();

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN v_deleted;
END;
$function$;

REVOKE ALL ON FUNCTION public.delete_all_notifications() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.delete_all_notifications() TO authenticated;

-- ------------------------------------------------------------
-- 4) Verification.
-- ------------------------------------------------------------

DO $verify$
DECLARE
  v_policy text;
  v_definition text;
BEGIN
  SELECT pg_get_expr(pol.polqual, pol.polrelid)
  INTO v_policy
  FROM pg_policy pol
  WHERE pol.polrelid = 'public.notifications'::regclass
    AND pol.polname = 'notifications_delete_own';

  IF v_policy IS NULL THEN
    RAISE EXCEPTION 'notifications_delete_own policy is missing';
  END IF;

  IF position('recipient_user_id' IN v_policy) = 0 THEN
    RAISE EXCEPTION
      'notifications_delete_own does not restrict the owner';
  END IF;

  SELECT pg_get_functiondef(
    'public.delete_notification(uuid)'::regprocedure
  )
  INTO v_definition;

  IF position('auth.uid()' IN v_definition) = 0 THEN
    RAISE EXCEPTION
      'delete_notification does not check the owner';
  END IF;

  SELECT pg_get_functiondef(
    'public.delete_all_notifications()'::regprocedure
  )
  INTO v_definition;

  IF position('auth.uid()' IN v_definition) = 0 THEN
    RAISE EXCEPTION
      'delete_all_notifications does not check the owner';
  END IF;
END;
$verify$;
