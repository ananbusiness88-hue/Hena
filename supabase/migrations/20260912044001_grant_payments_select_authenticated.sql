BEGIN;

GRANT SELECT ON TABLE public.payments
TO authenticated;

COMMIT;
