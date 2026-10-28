-- Hena: Customer delivery OTP
-- Generates a 4-digit delivery OTP when the customer requests it.
-- The plaintext OTP is returned only to the authenticated customer.
-- The stored value remains SHA-256 hashed through create_delivery_otp().

CREATE OR REPLACE FUNCTION public.customer_get_delivery_otp(
  p_order_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_otp text;
  v_customer_id uuid;
  v_driver_id uuid;
  v_status public.order_status;
BEGIN
  SELECT customer_id, driver_id, status
  INTO v_customer_id, v_driver_id, v_status
  FROM public.orders
  WHERE id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'OTP: الطلب غير موجود';
  END IF;

  IF v_customer_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'OTP: هذا الطلب ليس تابعًا لهذا الحساب';
  END IF;

  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'OTP: لم يتم تعيين مندوب للطلب';
  END IF;

  IF v_status <> 'out_for_delivery'::public.order_status THEN
    RAISE EXCEPTION
      'OTP: حالة الطلب الحالية هي % وليست out_for_delivery',
      v_status;
  END IF;

  v_otp := lpad(
    floor(random() * 10000)::int::text,
    4,
    '0'
  );

  PERFORM public.create_delivery_otp(
    p_order_id,
    v_otp
  );

  RETURN v_otp;
END;
$$;

REVOKE ALL ON FUNCTION public.customer_get_delivery_otp(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.customer_get_delivery_otp(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.customer_get_delivery_otp(uuid) TO authenticated;
