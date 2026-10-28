-- Hena: Harden profiles table privileges.
-- Anonymous clients must never have direct SELECT access.
-- Authenticated clients may SELECT, with RLS controlling which rows
-- they are actually allowed to see.

REVOKE SELECT ON TABLE public.profiles FROM anon;

GRANT SELECT ON TABLE public.profiles TO authenticated;