-- Hena: Restrict is_admin() execution to authenticated users only.

REVOKE EXECUTE ON FUNCTION public.is_admin() FROM anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
