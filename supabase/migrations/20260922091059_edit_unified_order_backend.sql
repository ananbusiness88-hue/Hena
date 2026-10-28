BEGIN;

-- ============================================================
-- HENA  EDIT UNIFIED ORDER BACKEND
-- Customer may edit the same Unified Order only while:
--   status = pending
--   created_at is within 90 seconds
--
-- The same orders.id and unified_order_number are preserved.
-- Only affected Store Parts are rebuilt.
-- ============================================================


-- ------------------------------------------------------------
-- 1) Allow the protected orders trigger to recognize the
--    dedicated server-side edit operation.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.protect_order_mutations()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $function$
DECLARE
  v_role public.user_role := public.current_user_role();
  v_all_parts_picked_up boolean := false;
  v_edit_mode boolean := COALESCE(
    current_setting('hena.edit_unified_order', true),
    'false'
  ) = 'true';
BEGIN

  IF public.is_admin() THEN
    RETURN NEW;
  END IF;


  -- ----------------------------------------------------------
  -- Dedicated Customer Edit Order server operation.
  -- Only subtotal / delivery_fee may change here.
  -- ----------------------------------------------------------

  IF v_edit_mode THEN

    IF v_role <> 'customer' THEN
      RAISE EXCEPTION 'Only customers can edit their orders';
    END IF;

    IF OLD.customer_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Customer cannot edit this order';
    END IF;

    IF OLD.status <> 'pending'::public.order_status
       OR NEW.status <> 'pending'::public.order_status
    THEN
      RAISE EXCEPTION 'Only pending orders can be edited';
    END IF;

    IF OLD.created_at < (now() - interval '90 seconds') THEN
      RAISE EXCEPTION 'The 90-second edit window has expired';
    END IF;

    IF NEW.customer_id IS DISTINCT FROM OLD.customer_id
       OR NEW.store_id IS DISTINCT FROM OLD.store_id
       OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
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
       OR NEW.unified_order_date IS DISTINCT FROM OLD.unified_order_date
       OR NEW.unified_order_number IS DISTINCT FROM OLD.unified_order_number
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
       OR NEW.status IS DISTINCT FROM OLD.status
    THEN
      RAISE EXCEPTION 'Edit Order can only change order totals';
    END IF;

    RETURN NEW;
  END IF;


  -- ----------------------------------------------------------
  -- Driver assignment.
  -- ----------------------------------------------------------

  IF v_role = 'driver'
     AND OLD.driver_id IS NULL
     AND NEW.driver_id = auth.uid()
     AND OLD.status = 'ready'::public.order_status
     AND NEW.status = 'assigned'::public.order_status
  THEN

    IF NEW.customer_id IS DISTINCT FROM OLD.customer_id
       OR NEW.store_id IS DISTINCT FROM OLD.store_id
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
      RAISE EXCEPTION 'Driver assignment cannot modify protected order fields';
    END IF;

    RETURN NEW;
  END IF;


  -- ----------------------------------------------------------
  -- Automatic Unified Order transition.
  -- ----------------------------------------------------------

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

    RAISE EXCEPTION
      'Order can move to out_for_delivery only when all store portions are picked_up';
  END IF;


  -- ----------------------------------------------------------
  -- Final delivery transition.
  -- ----------------------------------------------------------

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

    RAISE EXCEPTION
      'Order cannot be delivered until all store portions are picked_up';
  END IF;


  -- ----------------------------------------------------------
  -- Customer: cancellation only.
  -- ----------------------------------------------------------

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

    IF NEW.status <> 'cancelled'
       AND NEW.status <> OLD.status
    THEN
      RAISE EXCEPTION 'Customers can only cancel an order';
    END IF;

    RETURN NEW;
  END IF;


  -- ----------------------------------------------------------
  -- Store owners: status changes only.
  -- ----------------------------------------------------------

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


  -- ----------------------------------------------------------
  -- Driver: delivery status only.
  -- ----------------------------------------------------------

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


-- ------------------------------------------------------------
-- 2) Edit Unified Order RPC.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.edit_unified_order(
  p_order_id uuid,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
  v_item jsonb;
  v_product public.products%ROWTYPE;
  v_pricing public.product_pricing%ROWTYPE;
  v_offer public.offers%ROWTYPE;

  v_store_id uuid;
  v_product_id uuid;
  v_pricing_id uuid;
  v_offer_id uuid;

  v_qty numeric;
  v_unit_price numeric(12,2);

  v_subtotal numeric(12,2) := 0;
  v_store_count integer := 0;
  v_delivery_fee numeric(12,2) := 25;
  v_total numeric(12,2);

  v_store_ids uuid[];
  v_affected_stores uuid[];
  v_payment_exists boolean := false;
BEGIN

  -- ----------------------------------------------------------
  -- Authorization.
  -- ----------------------------------------------------------

  IF public.current_user_role() <> 'customer' THEN
    RAISE EXCEPTION 'Only customer accounts can edit orders';
  END IF;


  -- ----------------------------------------------------------
  -- Lock and validate the existing Unified Order.
  -- ----------------------------------------------------------

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
    AND customer_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found or does not belong to customer';
  END IF;

  IF v_order.status <> 'pending'::public.order_status THEN
    RAISE EXCEPTION 'Only pending orders can be edited';
  END IF;

  IF v_order.created_at < (now() - interval '90 seconds') THEN
    RAISE EXCEPTION 'The 90-second edit window has expired';
  END IF;


  -- ----------------------------------------------------------
  -- Validate item array.
  -- ----------------------------------------------------------

  IF jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0
  THEN
    RAISE EXCEPTION 'Order must contain at least one item';
  END IF;


  -- ----------------------------------------------------------
  -- Store count.
  -- ----------------------------------------------------------

  SELECT COUNT(DISTINCT (item ->> 'store_id')::uuid)
  INTO v_store_count
  FROM jsonb_array_elements(p_items) AS item;

  IF v_store_count < 1 THEN
    RAISE EXCEPTION 'Order must contain at least one store';
  END IF;


  -- ----------------------------------------------------------
  -- Validate stores.
  -- ----------------------------------------------------------

  IF EXISTS (
    SELECT 1
    FROM (
      SELECT DISTINCT
        (item ->> 'store_id')::uuid AS store_id
      FROM jsonb_array_elements(p_items) AS item
    ) requested_stores
    LEFT JOIN public.stores s
      ON s.id = requested_stores.store_id
    LEFT JOIN public.store_settings ss
      ON ss.store_id = requested_stores.store_id
    WHERE s.id IS NULL
       OR s.is_active = false
       OR COALESCE(ss.accepts_orders, true) = false
  ) THEN
    RAISE EXCEPTION
      'One or more stores are inactive or not accepting delivery orders';
  END IF;


  -- ----------------------------------------------------------
  -- Validate every item + calculate new subtotal.
  -- Server remains authoritative for price and offers.
  -- ----------------------------------------------------------

  FOR v_item IN
    SELECT value
    FROM jsonb_array_elements(p_items)
  LOOP

    v_store_id := (v_item ->> 'store_id')::uuid;
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_pricing_id := (v_item ->> 'pricing_id')::uuid;
    v_offer_id := NULLIF(v_item ->> 'offer_id', '')::uuid;
    v_qty := (v_item ->> 'quantity')::numeric;

    IF v_store_id IS NULL
       OR v_product_id IS NULL
       OR v_pricing_id IS NULL
       OR v_qty IS NULL
    THEN
      RAISE EXCEPTION
        'Every order item must include store_id, product_id, pricing_id and quantity';
    END IF;

    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'Invalid item quantity';
    END IF;

    SELECT *
    INTO v_product
    FROM public.products
    WHERE id = v_product_id
      AND store_id = v_store_id
      AND is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'Product not found, inactive, or belongs to another store';
    END IF;

    SELECT *
    INTO v_pricing
    FROM public.product_pricing
    WHERE id = v_pricing_id
      AND product_id = v_product_id
      AND is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'Pricing not found, inactive, or belongs to another product';
    END IF;

    IF v_pricing.pricing_type::text <> v_product.selling_method::text THEN
      RAISE EXCEPTION
        'Pricing type does not match product selling method';
    END IF;

    IF v_product.selling_method = 'weight'
       AND v_qty > 100
    THEN
      RAISE EXCEPTION 'Invalid weight quantity';
    END IF;

    IF v_offer_id IS NOT NULL THEN

      SELECT *
      INTO v_offer
      FROM public.offers
      WHERE id = v_offer_id
        AND product_id = v_product_id
        AND store_id = v_store_id
        AND pricing_id = v_pricing_id
        AND is_active = true
        AND now() >= start_date
        AND now() <= end_date;

      IF NOT FOUND THEN
        RAISE EXCEPTION
          'Offer not found, inactive, expired, or invalid for this product';
      END IF;

      v_unit_price := v_offer.offer_price;
    ELSE
      v_unit_price := v_pricing.price;
    END IF;

    IF v_product.selling_method = 'value' THEN
      v_subtotal := v_subtotal + v_qty;
    ELSE
      v_subtotal := v_subtotal + (v_unit_price * v_qty);
    END IF;

  END LOOP;


  -- ----------------------------------------------------------
  -- Delivery fee.
  -- 1-3 stores = 25
  -- each store after 3 = +5
  -- ----------------------------------------------------------

  IF v_store_count > 3 THEN
    v_delivery_fee :=
      25 + ((v_store_count - 3) * 5);
  END IF;


  -- ----------------------------------------------------------
  -- Find Stores whose item contents actually changed.
  -- Unaffected Store Parts stay untouched.
  -- ----------------------------------------------------------

  WITH old_grouped AS (
    SELECT
      oi.store_id,
      md5(
        string_agg(
          oi.product_id::text
          || '|'
          || oi.pricing_id::text
          || '|'
          || COALESCE(oi.offer_id::text, '')
          || '|'
          || oi.quantity::text,
          '||'
          ORDER BY
            oi.product_id,
            oi.pricing_id,
            COALESCE(oi.offer_id::text, ''),
            oi.quantity::text
        )
      ) AS signature
    FROM public.order_items oi
    WHERE oi.order_id = p_order_id
    GROUP BY oi.store_id
  ),
  new_grouped AS (
    SELECT
      (item ->> 'store_id')::uuid AS store_id,
      md5(
        string_agg(
          (item ->> 'product_id')
          || '|'
          || (item ->> 'pricing_id')
          || '|'
          || COALESCE(item ->> 'offer_id', '')
          || '|'
          || (item ->> 'quantity'),
          '||'
          ORDER BY
            item ->> 'product_id',
            item ->> 'pricing_id',
            COALESCE(item ->> 'offer_id', ''),
            item ->> 'quantity'
        )
      ) AS signature
    FROM jsonb_array_elements(p_items) AS item
    GROUP BY (item ->> 'store_id')::uuid
  )
  SELECT ARRAY(
    SELECT COALESCE(n.store_id, o.store_id)
    FROM new_grouped n
    FULL OUTER JOIN old_grouped o
      ON o.store_id = n.store_id
    WHERE n.signature IS DISTINCT FROM o.signature
  )
  INTO v_affected_stores;


  -- ----------------------------------------------------------
  -- Rebuild only affected Store Parts through order_items.
  -- Existing sync trigger handles Store Part creation/deletion.
  -- ----------------------------------------------------------

  IF v_affected_stores IS NULL THEN
    v_affected_stores := ARRAY[]::uuid[];
  END IF;

  FOREACH v_store_id IN ARRAY v_affected_stores
  LOOP

    DELETE FROM public.order_items
    WHERE order_id = p_order_id
      AND store_id = v_store_id;

    FOR v_item IN
      SELECT value
      FROM jsonb_array_elements(p_items) AS item
      WHERE (item ->> 'store_id')::uuid = v_store_id
    LOOP

      v_product_id := (v_item ->> 'product_id')::uuid;
      v_pricing_id := (v_item ->> 'pricing_id')::uuid;
      v_offer_id := NULLIF(v_item ->> 'offer_id', '')::uuid;
      v_qty := (v_item ->> 'quantity')::numeric;

      SELECT *
      INTO v_product
      FROM public.products
      WHERE id = v_product_id
        AND store_id = v_store_id
        AND is_active = true;

      IF v_offer_id IS NOT NULL THEN
        SELECT *
        INTO v_offer
        FROM public.offers
        WHERE id = v_offer_id
          AND product_id = v_product_id
          AND store_id = v_store_id
          AND pricing_id = v_pricing_id
          AND is_active = true
          AND now() >= start_date
          AND now() <= end_date;

        v_unit_price := v_offer.offer_price;
      ELSE
        SELECT price
        INTO v_unit_price
        FROM public.product_pricing
        WHERE id = v_pricing_id
          AND product_id = v_product_id
          AND is_active = true;
      END IF;

      INSERT INTO public.order_items (
        order_id,
        store_id,
        product_id,
        pricing_id,
        offer_id,
        product_name,
        unit_price,
        quantity,
        selling_method
      )
      VALUES (
        p_order_id,
        v_store_id,
        v_product_id,
        v_pricing_id,
        v_offer_id,
        v_product.name,
        v_unit_price,
        v_qty,
        v_product.selling_method
      );

    END LOOP;

  END LOOP;


  -- ----------------------------------------------------------
  -- Update Unified Order totals through dedicated server mode.
  -- ----------------------------------------------------------

  PERFORM set_config(
    'hena.edit_unified_order',
    'true',
    true
  );

  UPDATE public.orders
  SET
    subtotal = v_subtotal,
    delivery_fee = v_delivery_fee
  WHERE id = p_order_id;

  PERFORM set_config(
    'hena.edit_unified_order',
    'false',
    true
  );


  -- ----------------------------------------------------------
  -- Payment amount follows the same Unified Order total.
  -- ----------------------------------------------------------

  SELECT EXISTS (
    SELECT 1
    FROM public.payments
    WHERE order_id = p_order_id
  )
  INTO v_payment_exists;

  IF NOT v_payment_exists THEN
    RAISE EXCEPTION 'Payment record not found for order';
  END IF;

  SELECT total
  INTO v_total
  FROM public.orders
  WHERE id = p_order_id;

  UPDATE public.payments
  SET
    amount = v_total,
    updated_at = now()
  WHERE order_id = p_order_id;


  -- ----------------------------------------------------------
  -- Same Order ID + same Unified Order Number.
  -- ----------------------------------------------------------

  SELECT total
  INTO v_total
  FROM public.orders
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'order_id', p_order_id,
    'unified_order_number', v_order.unified_order_number,
    'subtotal', v_subtotal,
    'delivery_fee', v_delivery_fee,
    'total', v_total,
    'affected_store_ids', to_jsonb(v_affected_stores)
  );

END;
$function$;


-- ------------------------------------------------------------
-- 3) Function access.
-- ------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.edit_unified_order(uuid, jsonb)
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION public.edit_unified_order(uuid, jsonb)
FROM anon;

GRANT EXECUTE ON FUNCTION public.edit_unified_order(uuid, jsonb)
TO authenticated;


COMMIT;