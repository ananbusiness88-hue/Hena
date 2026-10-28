DROP FUNCTION IF EXISTS public.lookup_profile_by_phone(text);

CREATE FUNCTION public.lookup_profile_by_phone(p_phone text)
RETURNS TABLE (
  id uuid,
  phone text,
  email text,
  role public.user_role
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.id,
    p.phone,
    p.email,
    p.role
  FROM public.profiles p
  WHERE p.phone = p_phone
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.lookup_profile_by_phone(text)
TO anon, authenticated;
