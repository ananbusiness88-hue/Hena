-- ============================================================
-- HENA - Phase 1 (follow-up 4): reload the PostgREST schema cache.
--
-- Why this migration exists:
--   PostgREST decides which functions are callable per role from its cached
--   schema. After Phase 1 revoked EXECUTE on the public functions and
--   re-granted it to `authenticated`, the cache still reported
--   lookup_profile_by_phone as unavailable (HTTP 404 / PGRST203) even though
--   the catalog shows the correct grants:
--     authenticated -> EXECUTE
--     anon          -> none
--
--   The NOTIFY below asks PostgREST to rebuild its schema cache, so the
--   live API surface matches the catalog immediately.
--
--   This migration changes no data and no grants; it is safe to re-run.
-- ============================================================

BEGIN;

NOTIFY pgrst, 'reload schema';

DO $verify$
DECLARE
  v_anon_execute boolean;
  v_auth_execute boolean;
BEGIN
  SELECT bool_or(has_function_privilege('anon', p.oid, 'EXECUTE')) INTO v_anon_execute
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'lookup_profile_by_phone';

  SELECT bool_or(has_function_privilege('authenticated', p.oid, 'EXECUTE')) INTO v_auth_execute
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'lookup_profile_by_phone';

  IF v_anon_execute THEN
    RAISE EXCEPTION 'lookup_profile_by_phone must not be executable by anon';
  END IF;

  IF NOT v_auth_execute THEN
    RAISE EXCEPTION 'lookup_profile_by_phone must stay executable by authenticated';
  END IF;

  RAISE NOTICE 'PostgREST schema cache reload requested.';
END;
$verify$;

COMMIT;
