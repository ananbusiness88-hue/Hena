BEGIN;

GRANT UPDATE ON TABLE public.orders TO authenticated;

COMMIT;