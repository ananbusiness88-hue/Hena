BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'protect_order_mutations'
  ) THEN
    RAISE EXCEPTION
      'Required function public.protect_order_mutations() does not exist.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgrelid = 'public.orders'::regclass
      AND NOT tgisinternal
      AND tgname = 'trigger_protect_order_mutations'
  ) THEN

    CREATE TRIGGER trigger_protect_order_mutations
    BEFORE UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_order_mutations();

  END IF;
END
$$;

COMMIT;
