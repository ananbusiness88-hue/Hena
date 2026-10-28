BEGIN;

REVOKE INSERT ON TABLE public.order_status_history FROM PUBLIC;
REVOKE INSERT ON TABLE public.order_status_history FROM authenticated;
REVOKE INSERT ON TABLE public.order_status_history FROM anon;

ALTER FUNCTION public.record_order_status_change()
SECURITY DEFINER;

ALTER FUNCTION public.record_order_status_change()
SET search_path = public, pg_temp;

COMMIT;