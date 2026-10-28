-- ============================================================
-- HENA - Phase 1 (follow-up 3): compare phones on BOTH normalized sides.
--
-- Why this migration exists:
--   The boolean helpers compared `profiles.phone` (raw column value) against
--   the normalized input. Production accounts store the phone in E.164 form
--   ("+201001234567"), but accounts created through the Supabase Admin API
--   store it without the plus sign ("201001234567"). Only the raw comparison
--   matched, so those accounts were invisible to phone_exists() and
--   verify_account_phone_email().
--
--   The comparison now normalizes BOTH sides, so any storage format
--   (with or without "+", with spaces or dashes) matches the input.
--
--   The stored side is normalized inside the query, so the lookup can no
--   longer use a plain index on profiles.phone. profiles is a small table
--   and this function is only called during sign-in and registration, so a
--   sequential scan is acceptable. A functional index on the normalized
--   expression can be added later if profiling shows a need.
-- ============================================================

BEGIN;

-- ============================================================
-- SECTION 1 - Recreate the boolean helpers with symmetric normalization
-- ============================================================

CREATE OR REPLACE FUNCTION public.verify_account_phone_email(
  p_phone text,
  p_email text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE public.hena_normalize_phone(p.phone) = public.hena_normalize_phone(p_phone)
      AND lower(coalesce(p.email, '')) = lower(trim(coalesce(p_email, '')))
      AND p.is_active = true
  );
$function$;

CREATE OR REPLACE FUNCTION public.phone_exists(
  p_phone text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE public.hena_normalize_phone(p.phone) = public.hena_normalize_phone(p_phone)
  );
$function$;

GRANT EXECUTE ON FUNCTION public.verify_account_phone_email(text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.phone_exists(text) TO anon, authenticated, service_role;

-- ============================================================
-- SECTION 2 - Verification assertions
-- ============================================================

DO $verify$
DECLARE
  v_failed text;
  v_mismatched text;
BEGIN
  -- The normalizer must still produce the same results.
  SELECT string_agg(case_id, ', ') INTO v_failed
  FROM (
    VALUES
      ('plus-prefixed',    public.hena_normalize_phone('+201001234567'),  '+201001234567'),
      ('local-zero',       public.hena_normalize_phone('01001234567'),   '+201001234567'),
      ('country-zero',    public.hena_normalize_phone('201001234567'),   '+201001234567'),
      ('double-zero',     public.hena_normalize_phone('00201001234567'), '+201001234567'),
      ('with-spaces',     public.hena_normalize_phone('010 0123 4567'),  '+201001234567'),
      ('with-dashes',     public.hena_normalize_phone('010-0123-4567'),  '+201001234567'),
      ('empty',           public.hena_normalize_phone(''),              NULL),
      ('null',            public.hena_normalize_phone(NULL),            NULL)
  ) AS t(case_id, actual, expected)
  WHERE actual IS DISTINCT FROM expected;

  IF v_failed IS NOT NULL THEN
    RAISE EXCEPTION 'phone normalization is wrong for: %', v_failed;
  END IF;

  -- No stored profile may have a phone that normalizes to NULL or to an
  -- empty string, otherwise it can never be matched by the helpers.
  SELECT string_agg(phone, ', ') INTO v_mismatched
  FROM public.profiles
  WHERE phone IS NULL
     OR public.hena_normalize_phone(phone) IS NULL;

  IF v_mismatched IS NOT NULL THEN
    RAISE EXCEPTION 'profiles contain unusable phone values: %', v_mismatched;
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

  RAISE NOTICE 'Symmetric phone comparison verified successfully.';
END;
$verify$;

COMMIT;
