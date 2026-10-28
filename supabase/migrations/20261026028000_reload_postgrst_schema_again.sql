-- ============================================================
-- HENA - Phase 1 (follow-up 6): standalone PostgREST schema cache reload.
--
-- The previous reload notification was emitted inside the same transaction
-- that changed the grants, so PostgREST could rebuild its cache before the
-- new privileges were visible to its own connection. This migration does
-- nothing but send the notification, in its own committed transaction, so
-- the cache is rebuilt against the final state of the catalog.
-- ============================================================

BEGIN;

NOTIFY pgrst, 'reload schema';

COMMIT;
