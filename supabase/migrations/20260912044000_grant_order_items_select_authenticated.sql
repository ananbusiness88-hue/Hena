BEGIN;

GRANT SELECT ON TABLE public.order_items
TO authenticated;

COMMIT;
