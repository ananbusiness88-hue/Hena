-- Hena: Restore missing admin security foundation
--
-- The remote database is missing profiles.is_active even though
-- the historical security model expects it.
-- Restore the column first, then restore public.is_admin().

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.profiles.is_active IS
'Whether the user account is active and allowed to operate in Hena.';


CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'admin'
      AND is_active = true
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;