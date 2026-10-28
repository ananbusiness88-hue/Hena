-- Hena: Restore get_my_profile() RPC.
-- Returns only the authenticated user's own profile.

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS TABLE (
  id uuid,
  full_name text,
  phone text,
  email text,
  role public.user_role,
  avatar_url text,
  is_active boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.id,
    p.full_name,
    p.phone,
    p.email,
    p.role,
    p.avatar_url,
    p.is_active
  FROM public.profiles p
  WHERE p.id = auth.uid()
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_my_profile() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_my_profile() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;
