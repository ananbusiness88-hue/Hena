-- ============================================================================
-- Hena - phone sign-in resolution (fixes the broken phone password login)
-- ============================================================================
-- Problem
-- -------
-- The phone_password_login Edge Function looked the account up with a raw
-- PostgREST filter:
--
--     /rest/v1/profiles?select=id,is_active,email&phone=eq.+201001234567
--
-- but public.profiles.phone stores the number in the format the customer
-- typed ("01001234567"), so the filter never matched any account and every
-- phone sign-in returned 401 even with the right password.
--
-- The database helpers (phone_exists, verify_account_phone_email) already
-- compare the two sides symmetrically, through public.hena_normalize_phone.
-- This migration exposes the same comparison for the Edge Function, so the
-- lookup works for every storage format ("01001234567", "201001234567",
-- "+201001234567", with spaces or dashes).
--
-- The helper is restricted to service_role: it returns the email identity of
-- an account, so it must never be callable with the public key. The public
-- surface stays a single boolean, so an account cannot be enumerated.
--
-- Append-only: earlier migrations are left untouched, and a fresh
-- `supabase db reset` converges to the same end state.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 - Service only resolver
-- ============================================================================

CREATE OR REPLACE FUNCTION public.profile_auth_identity_by_phone(
  p_phone text
)
RETURNS TABLE (
  id uuid,
  email text,
  is_active boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT p.id, p.email, p.is_active
  FROM public.profiles p
  WHERE public.hena_normalize_phone(p.phone) =
        public.hena_normalize_phone(p_phone)
  LIMIT 1;
$function$;

COMMENT ON FUNCTION public.profile_auth_identity_by_phone(text) IS
  'Resolves a phone number to the account identity. service_role only: it returns the email identity used for the password grant.';

REVOKE ALL ON FUNCTION public.profile_auth_identity_by_phone(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.profile_auth_identity_by_phone(text) FROM anon;
REVOKE ALL ON FUNCTION public.profile_auth_identity_by_phone(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.profile_auth_identity_by_phone(text) TO service_role;

-- ============================================================================
-- SECTION 2 - Store the phone in E.164 for new accounts
-- ============================================================================
-- The trigger used to copy the phone straight from the user metadata, so a
-- new account kept the raw format the customer typed while older accounts
-- held different formats. Storing the normalized form keeps the data
-- consistent; the symmetric comparison keeps the old rows reachable.

CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $function$
DECLARE
  v_full_name text;
  v_phone text;
  v_email text;
BEGIN
  v_full_name := NULLIF(
    trim(NEW.raw_user_meta_data ->> 'full_name'),
    ''
  );

  v_phone := NULLIF(trim(NEW.phone), '');

  IF v_phone IS NULL THEN
    v_phone := NULLIF(
      trim(NEW.raw_user_meta_data ->> 'phone'),
      ''
    );
  END IF;

  IF v_phone IS NOT NULL THEN
    v_phone := public.hena_normalize_phone(v_phone);
  END IF;

  v_email := NULLIF(trim(NEW.email), '');

  IF v_email IS NULL THEN
    v_email := NULLIF(
      trim(NEW.raw_user_meta_data ->> 'email'),
      ''
    );
  END IF;

  IF v_full_name IS NULL THEN
    v_full_name := 'New Customer';
  END IF;

  IF v_phone IS NULL THEN
    RAISE EXCEPTION 'Phone number is required';
  END IF;

  IF v_email IS NULL THEN
    RAISE EXCEPTION 'Email address is required';
  END IF;

  INSERT INTO public.profiles (
    id,
    full_name,
    phone,
    email,
    role,
    phone_verified_at
  )
  VALUES (
    NEW.id,
    v_full_name,
    v_phone,
    v_email,
    'customer',
    NULL
  );

  RETURN NEW;
END;
$function$;

-- ============================================================================
-- SECTION 3 - Verification assertions
-- ============================================================================

DO $verify$
DECLARE
  v_failed text;
  v_has_anon boolean;
BEGIN
  -- The resolver must not be reachable with the public key.
  SELECT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'profile_auth_identity_by_phone'
      AND p.prosecdef = true
      AND has_function_privilege(
        'anon',
        p.oid,
        'EXECUTE'
      )
  )
  INTO v_has_anon;

  IF v_has_anon THEN
    RAISE EXCEPTION
      'profile_auth_identity_by_phone is executable by anon';
  END IF;

  -- The trigger must still store a normalized phone.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'handle_new_user'
      AND p.prosrc LIKE '%hena_normalize_phone%'
  ) THEN
    RAISE EXCEPTION
      'handle_new_user does not normalize the phone anymore';
  END IF;

  -- The resolver must find an account whatever the stored format is.
  SELECT string_agg(case_id, ', ') INTO v_failed
  FROM (
    VALUES
      ('local-zero',    '+201001234567'),
      ('country-zero',  '+201001234567'),
      ('plus-prefixed', '+201001234567'),
      ('double-zero',   '+201001234567')
  ) AS t(case_id, expected)
  WHERE public.hena_normalize_phone(
          CASE case_id
            WHEN 'local-zero'    THEN '01001234567'
            WHEN 'country-zero'  THEN '201001234567'
            WHEN 'plus-prefixed' THEN '+201001234567'
            ELSE '00201001234567'
          END
        ) IS DISTINCT FROM expected;

  IF v_failed IS NOT NULL THEN
    RAISE EXCEPTION
      'phone normalization is wrong for: %', v_failed;
  END IF;
END;
$verify$;

COMMIT;

-- PostgREST caches the function list, so it has to be told to reload.
NOTIFY pgrst, 'reload schema';
