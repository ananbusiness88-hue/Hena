BEGIN;

DROP POLICY IF EXISTS orders_update_customer ON public.orders;

CREATE POLICY orders_update_customer
ON public.orders
AS PERMISSIVE
FOR UPDATE
TO authenticated
USING (
  customer_id = auth.uid()
  AND status = ANY (
    ARRAY[
      'pending'::public.order_status,
      'confirmed'::public.order_status
    ]
  )
  AND created_at >= (now() - interval '90 seconds')
)
WITH CHECK (
  customer_id = auth.uid()
  AND status = ANY (
    ARRAY[
      'pending'::public.order_status,
      'confirmed'::public.order_status,
      'cancelled'::public.order_status
    ]
  )
  AND created_at >= (now() - interval '90 seconds')
);

COMMIT;