-- ============================================================
-- HENA - Phase 1 cleanup: remove the temporary audit test accounts.
--
-- During the Phase 1 verification a set of throwaway accounts was created
-- with the pattern hena.audit.*@example.com and the phone prefix
-- +2012345*. They must not remain in the production database.
--
-- The Supabase Admin API delete endpoint returns HTTP 500 on this project,
-- so the rows are removed directly here. auth.identities, auth.sessions
-- and the other auth tables cascade from auth.users.
-- ============================================================

BEGIN;

DO $cleanup$
DECLARE
  v_profiles integer;
  v_users integer;
BEGIN
  DELETE FROM public.profiles
  WHERE email LIKE 'hena.audit.%@example.com';

  GET DIAGNOSTICS v_profiles = ROW_COUNT;

  DELETE FROM auth.users
  WHERE email LIKE 'hena.audit.%@example.com';

  GET DIAGNOSTICS v_users = ROW_COUNT;

  RAISE NOTICE 'Removed % audit profiles and % audit auth users.', v_profiles, v_users;
END;
$cleanup$;

-- ============================================================
-- Verification: no audit account may survive
-- ============================================================

DO $verify$
DECLARE
  v_left text;
BEGIN
  SELECT string_agg(source, ', ') INTO v_left
  FROM (
    SELECT 'profiles:' || email AS source
    FROM public.profiles
    WHERE email LIKE 'hena.audit.%@example.com'
    UNION ALL
    SELECT 'auth.users:' || email
    FROM auth.users
    WHERE email LIKE 'hena.audit.%@example.com'
  ) leftovers;

  IF v_left IS NOT NULL THEN
    RAISE EXCEPTION 'audit accounts still present: %', v_left;
  END IF;

  RAISE NOTICE 'Audit test accounts fully removed.';
END;
$verify$;

COMMIT;
