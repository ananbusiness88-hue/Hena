BEGIN;

CREATE OR REPLACE FUNCTION public.is_store_owner_of_order(
  p_order_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.order_store_parts osp
    JOIN public.stores s
      ON s.id = osp.store_id
    WHERE osp.order_id = p_order_id
      AND s.owner_id = auth.uid()
  );
$function$;

REVOKE ALL ON FUNCTION public.is_store_owner_of_order(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.is_store_owner_of_order(uuid)
TO authenticated;


DROP POLICY IF EXISTS orders_select_store_owner
ON public.orders;

CREATE POLICY orders_select_store_owner
ON public.orders
FOR SELECT
TO authenticated
USING (
  public.is_store_owner_of_order(id)
);

COMMIT;
