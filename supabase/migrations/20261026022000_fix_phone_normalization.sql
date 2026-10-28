-- ============================================================
-- HENA - Phase 1 (follow-up 2): correct phone normalization.
--
-- Why this migration exists:
--   The first Phase 1 migration normalized the incoming phone number with
--   a CASE expression whose final branch always prefixed "+". A phone
--   that was already stored in E.164 form ("+201001234567") - which is
--   exactly what the Flutter client sends, because
--   _normalizeEgyptianPhone() keeps the "+" prefix - was therefore
--   normalized to "++201001234567" and never matched any profile.
--
--   Impact: verify_account_phone_email() and phone_exists() would always
--   return false, breaking the e-mail login binding check and the
--   registration duplicate check.
--
-- The normalization now mirrors the Edge Function phone_password_login
-- exactly (supabase/functions/phone_password_login/index.ts):
--   "00..."  -> "+..."
--   "+..."   -> unchanged
--   "20..."  -> "+20..."
--   "0..."   -> "+20..."
--   other    -> "+..."
--
-- Append-only: the earlier migrations are left untouched so the applied
-- history stays truthful, and a fresh `supabase db reset` still converges
-- to the same secure and correct end state.
-- ============================================================

BEGIN;

-- ============================================================
-- SECTION 1 - Shared, immutable phone normalizer
-- ============================================================

CREATE OR REPLACE FUNCTION public.hena_normalize_phone(
  p_phone text
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
STRICT
AS $function$
DECLARE
  v_value text;
BEGIN
  v_value := replace(
    replace(
      replace(
        replace(trim(coalesce(p_phone, '')), ' ', ''),
        '-', ''
      ),
      '(', ''
    ),
    ')', ''
  );

  IF v_value = '' THEN
    RETURN NULL;
  END IF;

  IF left(v_value, 2) = '00' THEN
    RETURN '+' || substr(v_value, 3);
  END IF;

  IF left(v_value, 1) = '+' THEN
    RETURN v_value;
  END IF;

  IF left(v_value, 2) = '20' THEN
    RETURN '+' || v_value;
  END IF;

  IF left(v_value, 1) = '0' THEN
    RETURN '+20' || substr(v_value, 2);
  END IF;

  RETURN '+' || v_value;
END;
$function$;

COMMENT ON FUNCTION public.hena_normalize_phone(text) IS
  'Normalizes an Egyptian phone number to E.164. Mirrors the phone_password_login Edge Function.';

-- ============================================================
-- SECTION 2 - Recreate the boolean helpers on top of the normalizer
-- ============================================================

CREATE OR REPLACE FUNCTION public.verify_account_phone_email(
  p_phone text,
  p_email text
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.phone = public.hena_normalize_phone(p_phone)
      AND lower(coalesce(p.email, '')) = lower(trim(coalesce(p_email, '')))
      AND p.is_active = true
  );
$function$;

CREATE OR REPLACE FUNCTION public.phone_exists(
  p_phone text
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.phone = public.hena_normalize_phone(p_phone)
  );
$function$;

-- CREATE OR REPLACE keeps the existing ACLs, but re-assert them so the
-- grants are explicit and survive a manual REVOKE.
GRANT EXECUTE ON FUNCTION public.verify_account_phone_email(text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.phone_exists(text) TO anon, authenticated, service_role;

-- ============================================================
-- SECTION 3 - Verification assertions
-- ============================================================

DO $verify$
DECLARE
  v_failed text;
BEGIN
  -- The normalizer must handle every format the Flutter client can send.
  SELECT string_agg(case_id, ', ') INTO v_failed
  FROM (
    VALUES
      ('plus-prefixed',   public.hena_normalize_phone('+201001234567'), '+201001234567'),
      ('local-zero',      public.hena_normalize_phone('01001234567'),  '+201001234567'),
      ('country-zero',   public.hena_normalize_phone('201001234567'),  '+201001234567'),
      ('double-zero',    public.hena_normalize_phone('00201001234567'),'+201001234567'),
      ('with-spaces',    public.hena_normalize_phone('010 0123 4567'), '+201001234567'),
      ('with-dashes',    public.hena_normalize_phone('010-0123-4567'), '+201001234567'),
      ('empty',          public.hena_normalize_phone(''),             NULL),
      ('null',           public.hena_normalize_phone(NULL),           NULL)
  ) AS t(case_id, actual, expected)
  WHERE actual IS DISTINCT FROM expected;

  IF v_failed IS NOT NULL THEN
    RAISE EXCEPTION 'phone normalization is wrong for: %', v_failed;
  END IF;

  -- The PII-returning lookup must stay closed to the public key.
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'lookup_profile_by_phone'
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
  ) THEN
    RAISE EXCEPTION 'lookup_profile_by_phone is executable by anon';
  END IF;

  -- The two boolean helpers must stay reachable pre-authentication.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'verify_account_phone_email'
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
  ) OR NOT EXISTS (
    SELECT 1
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'phone_exists'
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
  ) THEN
    RAISE EXCEPTION 'boolean replacement functions are not reachable by anon';
  END IF;

  RAISE NOTICE 'Phone normalization verified successfully.';
END;
$verify$;

COMMIT;
