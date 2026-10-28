-- ============================================================
-- HENA - Phase 1 (follow-up 5): restore EXECUTE for the infrastructure
-- roles that PostgREST and Supabase Auth need.
--
-- Why this migration exists:
--   PostgREST builds its schema cache using the privileges of the role it
--   connects as (`authenticator`). Phase 1 revoked EXECUTE from PUBLIC on
--   all public functions, which also removed it from `authenticator`:
--
--     get_my_profile EXECUTE -> anon=no, authenticated=yes, service_role=yes,
--                               authenticator=NO
--
--   Because `authenticator` could no longer see the functions, they were
--   dropped from the PostgREST schema cache and every call returned
--   HTTP 404 (PGRST202) - including `get_my_profile`, which every signed-in
--   session calls.
--
--   Granting EXECUTE to `authenticator` puts the functions back into the
--   cache. PostgREST still enforces the real caller's privileges per
--   request, so `anon` remains unable to call the privileged functions.
-- ============================================================

BEGIN;

-- ============================================================
-- SECTION 1 - Infrastructure roles
-- ============================================================

GRANT USAGE ON SCHEMA public TO authenticator;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticator;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO supabase_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO supabase_auth_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- The functions created by the earlier Phase 1 migrations.
GRANT EXECUTE ON FUNCTION public.hena_normalize_phone(text) TO authenticator, service_role, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_account_phone_email(text, text) TO authenticator, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.phone_exists(text) TO authenticator, anon, authenticated, service_role;

-- Future functions must be visible to PostgREST as well.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated;

-- ============================================================
-- SECTION 2 - Reload the PostgREST schema cache
-- ============================================================

NOTIFY pgrst, 'reload schema';

-- ============================================================
-- SECTION 3 - Verification assertions
-- ============================================================

DO $verify$
DECLARE
  v_missing text;
BEGIN
  -- Every infrastructure role that PostgREST or Auth relies on must be able
  -- to see the public functions, otherwise they vanish from the schema cache.
  SELECT string_agg(missing, ', ') INTO v_missing
  FROM (
    SELECT expected || ':' || fname AS missing
    FROM unnest(ARRAY['authenticator', 'supabase_auth_admin', 'service_role', 'authenticated']) AS expected
    CROSS JOIN unnest(ARRAY['get_my_profile', 'current_user_role', 'lookup_profile_by_phone']) AS fname
    WHERE NOT EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.proname = fname
        AND has_function_privilege(expected, p.oid, 'EXECUTE')
    )
  ) gaps;

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'role/function pairs without EXECUTE: %', v_missing;
  END IF;

  -- anon must still be locked out of the PII lookup.
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

  RAISE NOTICE 'Infrastructure role grants verified successfully.';
END;
$verify$;

COMMIT;
