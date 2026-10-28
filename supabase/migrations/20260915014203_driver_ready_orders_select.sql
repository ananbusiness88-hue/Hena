DROP POLICY IF EXISTS orders_select_driver
ON public.orders;

CREATE POLICY orders_select_driver
ON public.orders
FOR SELECT
TO authenticated
USING (
  driver_id = auth.uid()
  OR (
    status = 'ready'::public.order_status
    AND driver_id IS NULL
  )
);