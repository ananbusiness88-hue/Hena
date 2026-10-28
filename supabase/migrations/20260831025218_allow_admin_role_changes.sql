-- Hena: allow admins to perform controlled role changes.
-- Regular users remain unable to change their own role.

CREATE OR REPLACE FUNCTION public.prevent_profile_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Admin role changes are allowed only through an authenticated
  -- admin-controlled database workflow such as
  -- admin_review_role_application().
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Users cannot change their own role';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.prevent_profile_role_change() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.prevent_profile_role_change() FROM anon;
REVOKE ALL ON FUNCTION public.prevent_profile_role_change() FROM authenticated;