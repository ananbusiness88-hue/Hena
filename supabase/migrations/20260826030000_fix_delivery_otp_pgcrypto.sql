-- Hena: Fix delivery OTP pgcrypto dependency
--
-- The pgcrypto extension is installed in the "extensions" schema.
-- OTP functions use digest(), so reference extensions.digest() explicitly.
--
-- Do not change search_path to include extensions globally.
-- Keep the security boundary of these SECURITY DEFINER functions intact.

CREATE EXTENSION IF NOT EXISTS pgcrypto
WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.create_delivery_otp(
  p_order_id uuid,
  p_plain_otp text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_driver_id uuid;
BEGIN
  SELECT driver_id
  INTO v_driver_id
  FROM public.orders
  WHERE id = p_order_id
    AND status IN ('assigned', 'picked_up', 'out_for_delivery');

  IF NOT FOUND OR v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Order is not eligible for OTP creation';
  END IF;

  IF NOT (
    p_plain_otp ~ '^[0-9]{4}$'
  ) THEN
    RAISE EXCEPTION 'OTP must contain exactly 4 digits';
  END IF;

  INSERT INTO public.order_delivery_otp (
    order_id,
    otp_hash,
    expires_at
  )
  VALUES (
    p_order_id,
    encode(extensions.digest(p_plain_otp, 'sha256'), 'hex'),
    now() + interval '30 minutes'
  )
  ON CONFLICT (order_id)
  DO UPDATE SET
    otp_hash = EXCLUDED.otp_hash,
    expires_at = EXCLUDED.expires_at,
    attempts_count = 0,
    verified_at = NULL,
    updated_at = now();
END;
$function$;


CREATE OR REPLACE FUNCTION public.verify_delivery_otp(
  p_order_id uuid,
  p_plain_otp text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_otp public.order_delivery_otp%ROWTYPE;
  v_hash text;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.orders
    WHERE id = p_order_id
      AND customer_id = auth.uid()
      AND status = 'out_for_delivery'
  ) THEN
    RETURN false;
  END IF;

  SELECT *
  INTO v_otp
  FROM public.order_delivery_otp
  WHERE order_id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_otp.verified_at IS NOT NULL THEN
    RETURN false;
  END IF;

  IF now() >= v_otp.expires_at THEN
    RETURN false;
  END IF;

  IF v_otp.attempts_count >= v_otp.max_attempts THEN
    RETURN false;
  END IF;

  IF NOT (
    p_plain_otp ~ '^[0-9]{4}$'
  ) THEN
    UPDATE public.order_delivery_otp
    SET attempts_count = attempts_count + 1,
        updated_at = now()
    WHERE order_id = p_order_id;

    RETURN false;
  END IF;

  v_hash := encode(
    extensions.digest(p_plain_otp, 'sha256'),
    'hex'
  );

  IF v_hash <> v_otp.otp_hash THEN
    UPDATE public.order_delivery_otp
    SET attempts_count = attempts_count + 1,
        updated_at = now()
    WHERE order_id = p_order_id;

    RETURN false;
  END IF;

  UPDATE public.order_delivery_otp
  SET verified_at = now(),
      updated_at = now()
  WHERE order_id = p_order_id;

  UPDATE public.orders
  SET status = 'delivered',
      updated_at = now()
  WHERE id = p_order_id
    AND status = 'out_for_delivery';

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$function$;