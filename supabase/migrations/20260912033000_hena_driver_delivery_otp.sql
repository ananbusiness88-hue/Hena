BEGIN;

CREATE OR REPLACE FUNCTION public.protect_order_mutations()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
  v_role public.user_role := public.current_user_role();
  v_all_parts_picked_up boolean := false;
BEGIN
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  /*
    Automatic Unified Order transition:
    allow out_for_delivery only when all Store Portions are picked_up.
  */
  IF v_role = 'store_owner'
     AND OLD.status IS DISTINCT FROM NEW.status
     AND NEW.status = 'out_for_delivery'::public.order_status
  THEN
    SELECT
      EXISTS (
        SELECT 1
        FROM public.order_store_parts osp
        WHERE osp.order_id = NEW.id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.order_store_parts osp
        WHERE osp.order_id = NEW.id
          AND osp.status <> 'picked_up'::public.store_order_part_status
      )
    INTO v_all_parts_picked_up;

    IF v_all_parts_picked_up THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Order can move to out_for_delivery only when all store portions are picked_up';
  END IF;

  /*
    Final delivery transition:
    only the assigned driver may move out_for_delivery -> delivered.
  */
  IF v_role = 'driver'
     AND OLD.status = 'out_for_delivery'::public.order_status
     AND NEW.status = 'delivered'::public.order_status
  THEN
    SELECT
      EXISTS (
        SELECT 1
        FROM public.order_store_parts osp
        WHERE osp.order_id = NEW.id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.order_store_parts osp
        WHERE osp.order_id = NEW.id
          AND osp.status <> 'picked_up'::public.store_order_part_status
      )
    INTO v_all_parts_picked_up;

    IF v_all_parts_picked_up THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Order cannot be delivered until all store portions are picked_up';
  END IF;

  /*
    Customer: cancellation only.
  */
  IF v_role = 'customer' THEN
    IF NEW.customer_id IS DISTINCT FROM OLD.customer_id
       OR NEW.store_id IS DISTINCT FROM OLD.store_id
       OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
       OR NEW.subtotal IS DISTINCT FROM OLD.subtotal
       OR NEW.delivery_fee IS DISTINCT FROM OLD.delivery_fee
       OR NEW.extra_fee IS DISTINCT FROM OLD.extra_fee
       OR NEW.customer_notes IS DISTINCT FROM OLD.customer_notes
       OR NEW.delivery_points IS DISTINCT FROM OLD.delivery_points
       OR NEW.delivery_recipient_name IS DISTINCT FROM OLD.delivery_recipient_name
       OR NEW.delivery_phone IS DISTINCT FROM OLD.delivery_phone
       OR NEW.delivery_governorate IS DISTINCT FROM OLD.delivery_governorate
       OR NEW.delivery_city IS DISTINCT FROM OLD.delivery_city
       OR NEW.delivery_area IS DISTINCT FROM OLD.delivery_area
       OR NEW.delivery_building_number IS DISTINCT FROM OLD.delivery_building_number
       OR NEW.delivery_apartment_number IS DISTINCT FROM OLD.delivery_apartment_number
       OR NEW.delivery_address_details IS DISTINCT FROM OLD.delivery_address_details
    THEN
      RAISE EXCEPTION 'Customers cannot modify order data';
    END IF;

    IF NEW.status <> 'cancelled' AND NEW.status <> OLD.status THEN
      RAISE EXCEPTION 'Customers can only cancel an order';
    END IF;

    RETURN NEW;
  END IF;

  /*
    Store owners: status changes only.
  */
  IF v_role = 'store_owner' THEN
    IF NEW.customer_id IS DISTINCT FROM OLD.customer_id
       OR NEW.store_id IS DISTINCT FROM OLD.store_id
       OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
       OR NEW.subtotal IS DISTINCT FROM OLD.subtotal
       OR NEW.delivery_fee IS DISTINCT FROM OLD.delivery_fee
       OR NEW.extra_fee IS DISTINCT FROM OLD.extra_fee
       OR NEW.customer_notes IS DISTINCT FROM OLD.customer_notes
       OR NEW.delivery_points IS DISTINCT FROM OLD.delivery_points
       OR NEW.delivery_recipient_name IS DISTINCT FROM OLD.delivery_recipient_name
       OR NEW.delivery_phone IS DISTINCT FROM OLD.delivery_phone
       OR NEW.delivery_governorate IS DISTINCT FROM OLD.delivery_governorate
       OR NEW.delivery_city IS DISTINCT FROM OLD.delivery_city
       OR NEW.delivery_area IS DISTINCT FROM OLD.delivery_area
       OR NEW.delivery_building_number IS DISTINCT FROM OLD.delivery_building_number
       OR NEW.delivery_apartment_number IS DISTINCT FROM OLD.delivery_apartment_number
       OR NEW.delivery_address_details IS DISTINCT FROM OLD.delivery_address_details
    THEN
      RAISE EXCEPTION 'Store owners cannot modify protected order fields';
    END IF;

    IF NEW.status NOT IN (
         'confirmed',
         'preparing',
         'ready',
         'cancelled'
       )
       AND NEW.status <> OLD.status
    THEN
      RAISE EXCEPTION 'Invalid store order status transition';
    END IF;

    RETURN NEW;
  END IF;

  /*
    Driver: delivery status only.
  */
  IF v_role = 'driver' THEN
    IF NEW.customer_id IS DISTINCT FROM OLD.customer_id
       OR NEW.store_id IS DISTINCT FROM OLD.store_id
       OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
       OR NEW.subtotal IS DISTINCT FROM OLD.subtotal
       OR NEW.delivery_fee IS DISTINCT FROM OLD.delivery_fee
       OR NEW.extra_fee IS DISTINCT FROM OLD.extra_fee
       OR NEW.customer_notes IS DISTINCT FROM OLD.customer_notes
       OR NEW.delivery_points IS DISTINCT FROM OLD.delivery_points
       OR NEW.delivery_recipient_name IS DISTINCT FROM OLD.delivery_recipient_name
       OR NEW.delivery_phone IS DISTINCT FROM OLD.delivery_phone
       OR NEW.delivery_governorate IS DISTINCT FROM OLD.delivery_governorate
       OR NEW.delivery_city IS DISTINCT FROM OLD.delivery_city
       OR NEW.delivery_area IS DISTINCT FROM OLD.delivery_area
       OR NEW.delivery_building_number IS DISTINCT FROM OLD.delivery_building_number
       OR NEW.delivery_apartment_number IS DISTINCT FROM OLD.delivery_apartment_number
       OR NEW.delivery_address_details IS DISTINCT FROM OLD.delivery_address_details
    THEN
      RAISE EXCEPTION 'Drivers cannot modify protected order fields';
    END IF;

    IF NEW.status NOT IN (
         'assigned',
         'picked_up',
         'out_for_delivery',
         'delivered'
       )
       AND NEW.status <> OLD.status
    THEN
      RAISE EXCEPTION 'Invalid driver order status transition';
    END IF;

    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Unauthorized order mutation';
END;
$function$;


/*
  Customer generates a delivery OTP.
  The plain OTP is returned only to the authenticated owner of the order.
  Only the SHA-256 hash is persisted.
*/
CREATE OR REPLACE FUNCTION public.customer_create_delivery_otp(
  p_order_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_bytes bytea;
  v_number integer;
  v_plain_otp text;
  v_order_status public.order_status;
BEGIN
  SELECT status
  INTO v_order_status
  FROM public.orders
  WHERE id = p_order_id
    AND customer_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order_status NOT IN (
      'ready'::public.order_status,
      'out_for_delivery'::public.order_status
  ) THEN
    RAISE EXCEPTION 'OTP is only available when the order is ready for shipping or out for delivery';
  END IF;

  v_bytes := extensions.gen_random_bytes(2);

  v_number :=
      get_byte(v_bytes, 0) * 256
    + get_byte(v_bytes, 1);

  v_plain_otp := lpad(
    (v_number % 10000)::text,
    4,
    '0'
  );

  INSERT INTO public.order_delivery_otp (
    order_id,
    otp_hash,
    expires_at,
    attempts_count,
    max_attempts,
    verified_at
  )
  VALUES (
    p_order_id,
    encode(extensions.digest(v_plain_otp, 'sha256'), 'hex'),
    now() + interval '24 hours',
    0,
    5,
    NULL
  )
  ON CONFLICT (order_id)
  DO UPDATE SET
    otp_hash = EXCLUDED.otp_hash,
    expires_at = EXCLUDED.expires_at,
    attempts_count = 0,
    max_attempts = EXCLUDED.max_attempts,
    verified_at = NULL,
    updated_at = now();

  RETURN v_plain_otp;
END;
$function$;


/*
  Only the assigned driver may verify the customer's OTP.
  A correct OTP completes the Unified Order.
*/
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
      AND driver_id = auth.uid()
      AND status = 'out_for_delivery'::public.order_status
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

  IF NOT (p_plain_otp ~ '^[0-9]{4}$') THEN
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

  UPDATE public.orders
  SET status = 'delivered'::public.order_status
  WHERE id = p_order_id
    AND driver_id = auth.uid()
    AND status = 'out_for_delivery'::public.order_status;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  UPDATE public.order_delivery_otp
  SET verified_at = now(),
      updated_at = now()
  WHERE order_id = p_order_id;

  RETURN true;
END;
$function$;


REVOKE ALL ON FUNCTION public.customer_create_delivery_otp(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.customer_create_delivery_otp(uuid)
TO authenticated;


REVOKE ALL ON FUNCTION public.verify_delivery_otp(uuid, text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.verify_delivery_otp(uuid, text)
TO authenticated;


REVOKE ALL ON FUNCTION public.create_delivery_otp(uuid, text)
FROM PUBLIC, anon, authenticated;

COMMIT;
