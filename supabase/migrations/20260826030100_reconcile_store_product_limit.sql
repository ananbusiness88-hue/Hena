-- Hena: Reconcile Store Product Capacity
--
-- The historical product-limit migrations are already recorded in
-- migration history but their local SQL files are empty.
-- This migration establishes the actual schema safely.

ALTER TABLE public.stores
ADD COLUMN IF NOT EXISTS product_limit integer NOT NULL DEFAULT 100;

ALTER TABLE public.stores
DROP CONSTRAINT IF EXISTS stores_product_limit_check;

ALTER TABLE public.stores
ADD CONSTRAINT stores_product_limit_check
CHECK (product_limit >= 0);

COMMENT ON COLUMN public.stores.product_limit IS
'Maximum number of active products this store is allowed to expose. Controlled by Super Admin.';


CREATE OR REPLACE FUNCTION public.enforce_store_product_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  current_active_products integer;
  allowed_product_limit integer;
BEGIN
  SELECT s.product_limit
  INTO allowed_product_limit
  FROM public.stores s
  WHERE s.id = NEW.store_id
    AND s.is_active = true;

  IF allowed_product_limit IS NULL THEN
    RAISE EXCEPTION 'Store is inactive or does not exist';
  END IF;

  SELECT COUNT(*)
  INTO current_active_products
  FROM public.products p
  WHERE p.store_id = NEW.store_id
    AND p.is_active = true
    AND p.id <> COALESCE(
      NEW.id,
      '00000000-0000-0000-0000-000000000000'::uuid
    );

  IF NEW.is_active = true
     AND current_active_products >= allowed_product_limit THEN
    RAISE EXCEPTION
      'Store product limit reached (% active products allowed)',
      allowed_product_limit;
  END IF;

  RETURN NEW;
END;
$function$;


DROP TRIGGER IF EXISTS enforce_store_product_limit_trigger
ON public.products;

CREATE TRIGGER enforce_store_product_limit_trigger
BEFORE INSERT OR UPDATE OF store_id, is_active
ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.enforce_store_product_limit();