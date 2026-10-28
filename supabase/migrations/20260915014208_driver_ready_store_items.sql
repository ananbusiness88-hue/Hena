DROP POLICY IF EXISTS order_items_select_driver
ON public.order_items;

CREATE POLICY order_items_select_driver
ON public.order_items
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.orders o
    WHERE o.id = order_items.order_id
      AND (
        o.driver_id = auth.uid()
        OR (
          o.status = 'ready'::public.order_status
          AND o.driver_id IS NULL
        )
      )
  )
);

DROP POLICY IF EXISTS order_store_parts_select_driver
ON public.order_store_parts;

CREATE POLICY order_store_parts_select_driver
ON public.order_store_parts
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.orders o
    WHERE o.id = order_store_parts.order_id
      AND (
        o.driver_id = auth.uid()
        OR (
          o.status = 'ready'::public.order_status
          AND o.driver_id IS NULL
        )
      )
  )
);