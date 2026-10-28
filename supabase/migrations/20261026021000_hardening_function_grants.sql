-- ============================================================
-- HENA - Phase 1 (follow-up): complete the least-privilege grants
-- on functions.
--
-- Why this migration exists:
--   20261026020000_security_hardening_phase1.sql executed
--   `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC`,
--   which removes the implicit world-executable privilege but does NOT
--   remove the DIRECT grants that `sync_local_privileges.sql` had
--   already given to the `anon` role (e.g.
--   `GRANT ALL ON FUNCTION public.admin_review_payment(...) TO anon`).
--
--   Post-migration verification caught this: the `anon` role could still
--   EXECUTE the privileged RPCs. They are protected by internal guards
--   (`is_admin()` / `auth.uid()`), so they were not exploitable, but the
--   public API key that ships inside the APK should never be able to
--   attempt them.
--
-- This migration revokes the direct `anon` grants and restores the
-- small read-only whitelist. It is idempotent and also makes a fresh
-- `supabase db reset` converge to the same secure state.
-- ============================================================

BEGIN;

-- ============================================================
-- SECTION 1 - Remove every direct anon grant on public functions
-- ============================================================

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- ============================================================
-- SECTION 2 - Restore the intended grants
-- ============================================================

-- Authenticated users and the service role keep full function access.
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- Trigger helpers invoked by Supabase Auth internals.
DO $block$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    EXECUTE 'GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO supabase_auth_admin';
  END IF;
END;
$block$;

-- anon whitelist: caller-scoped helpers and public configuration only.
-- None of these expose personal data.
GRANT EXECUTE ON FUNCTION public.current_user_role() TO anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon;
GRANT EXECUTE ON FUNCTION public.get_delivery_settings() TO anon;
GRANT EXECUTE ON FUNCTION public.calculate_delivery_fee(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.calculate_delivery_area_surcharge(text) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_account_phone_email(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.phone_exists(text) TO anon;

-- Future functions must not become world-executable.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon;

-- ============================================================
-- SECTION 3 - Verification assertions
-- ============================================================

DO $verify$
DECLARE
  v_leaked_functions text;
  v_missing_whitelist text;
BEGIN
  -- 1. anon must not be able to EXECUTE any privileged function
  SELECT string_agg(p.proname, ', ') INTO v_leaked_functions
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND has_function_privilege('anon', p.oid, 'EXECUTE')
    AND p.proname NOT IN (
      'current_user_role',
      'is_admin',
      'get_delivery_settings',
      'calculate_delivery_fee',
      'calculate_delivery_area_surcharge',
      'verify_account_phone_email',
      'phone_exists'
    );

  IF v_leaked_functions IS NOT NULL THEN
    RAISE EXCEPTION 'anon can still execute privileged functions: %', v_leaked_functions;
  END IF;

  -- 2. the whitelist must stay reachable, otherwise sign-in breaks
  SELECT string_agg(fn, ', ') INTO v_missing_whitelist
  FROM unnest(ARRAY[
    'current_user_role',
    'is_admin',
    'get_delivery_settings',
    'calculate_delivery_fee',
    'calculate_delivery_area_surcharge',
    'verify_account_phone_email',
    'phone_exists'
  ]) AS fn
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = fn
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
  );

  IF v_missing_whitelist IS NOT NULL THEN
    RAISE EXCEPTION 'anon whitelist functions are no longer reachable: %', v_missing_whitelist;
  END IF;

  -- 3. the PII-returning lookup must stay closed
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'lookup_profile_by_phone'
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
  ) THEN
    RAISE EXCEPTION 'lookup_profile_by_phone is executable by anon again';
  END IF;

  RAISE NOTICE 'Function least-privilege grants verified successfully.';
END;
$verify$;

COMMIT;
