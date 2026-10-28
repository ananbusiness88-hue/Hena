-- ============================================================
-- HENA CHECKOUT FOUNDATION
-- Atomic Unified Checkout
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1) Harden order-item validation around pricing + offers.
--    The trigger already exists; we only replace its function.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.validate_order_item()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $function$
DECLARE
  v_product public.products%ROWTYPE;
  v_pricing public.product_pricing%ROWTYPE;
  v_offer public.offers%ROWTYPE;
BEGIN
  -- Product must belong to the requested store.
  SELECT *
  INTO v_product
  FROM public.products
  WHERE id = NEW.product_id
    AND store_id = NEW.store_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product does not belong to this store';
  END IF;

  IF NOT v_product.is_active THEN
    RAISE EXCEPTION 'Product is inactive';
  END IF;

  -- Selling method must match the product.
  IF NEW.selling_method <> v_product.selling_method THEN
    RAISE EXCEPTION 'Selling method does not match product';
  END IF;

  -- Pricing must exist, be active, and belong to this product.
  SELECT *
  INTO v_pricing
  FROM public.product_pricing
  WHERE id = NEW.pricing_id
    AND product_id = NEW.product_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pricing does not belong to this product';
  END IF;

  IF NOT v_pricing.is_active THEN
    RAISE EXCEPTION 'Pricing is inactive';
  END IF;

  -- Pricing type must match the product selling method.
  IF v_pricing.pricing_type::text <> NEW.selling_method::text THEN
    RAISE EXCEPTION 'Pricing type does not match selling method';
  END IF;

  -- Quantity validation.
  IF NEW.quantity IS NULL OR NEW.quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be greater than zero';
  END IF;

  IF NEW.selling_method = 'weight'
     AND NEW.quantity > 100
  THEN
    RAISE EXCEPTION 'Invalid weight quantity';
  END IF;

  -- Optional offer validation.
  IF NEW.offer_id IS NOT NULL THEN

    SELECT *
    INTO v_offer
    FROM public.offers
    WHERE id = NEW.offer_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Offer not found';
    END IF;

    IF NOT v_offer.is_active THEN
      RAISE EXCEPTION 'Offer is inactive';
    END IF;

    IF v_offer.product_id <> NEW.product_id THEN
      RAISE EXCEPTION 'Offer does not belong to this product';
    END IF;

    IF v_offer.store_id <> NEW.store_id THEN
      RAISE EXCEPTION 'Offer does not belong to this store';
    END IF;

    IF v_offer.pricing_id <> NEW.pricing_id THEN
      RAISE EXCEPTION 'Offer does not belong to this pricing';
    END IF;

    IF now() < v_offer.start_date
       OR now() > v_offer.end_date
    THEN
      RAISE EXCEPTION 'Offer is not currently active';
    END IF;

    NEW.unit_price := v_offer.offer_price;
  ELSE
    NEW.unit_price := v_pricing.price;
  END IF;

  NEW.product_name := v_product.name;

  RETURN NEW;
END;
$function$;


-- ------------------------------------------------------------
-- 2) Remove obsolete 3-parameter checkout RPC.
-- ------------------------------------------------------------

DROP FUNCTION IF EXISTS public.create_unified_order(
  uuid,
  jsonb,
  text
);


-- ------------------------------------------------------------
-- 3) Atomic Unified Checkout RPC
--
-- Client supplies:
--   address_id
--   items
--   payment_method
--   notes
--
-- Database calculates:
--   prices
--   item totals
--   subtotal
--   delivery fee
--   total
--   unified order number
--   payment amount
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_unified_order(
  p_address_id uuid,
  p_items jsonb,
  p_payment_method public.payment_method,
  p_customer_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_order_id uuid;
  v_address public.addresses%ROWTYPE;
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

  v_order_date date :=
    ((now() AT TIME ZONE 'Africa/Cairo')::date);
BEGIN

  -- ----------------------------------------------------------
  -- A) Authorization
  -- ----------------------------------------------------------

  IF public.current_user_role() NOT IN ('customer', 'store_owner') THEN
    RAISE EXCEPTION
      'Only customer or store_owner accounts can create customer orders';
  END IF;


  -- ----------------------------------------------------------
  -- B) Items must be a non-empty JSON array.
  -- ----------------------------------------------------------

  IF jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0
  THEN
    RAISE EXCEPTION 'Order must contain at least one item';
  END IF;


  -- ----------------------------------------------------------
  -- C) Address must belong to authenticated user.
  -- ----------------------------------------------------------

  SELECT *
  INTO v_address
  FROM public.addresses
  WHERE id = p_address_id
    AND user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Delivery address not found';
  END IF;


  -- ----------------------------------------------------------
  -- D) Required item fields.
  -- ----------------------------------------------------------

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_items) AS item
    WHERE NULLIF(item ->> 'store_id', '') IS NULL
  ) THEN
    RAISE EXCEPTION 'Every order item must include store_id';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_items) AS item
    WHERE NULLIF(item ->> 'product_id', '') IS NULL
  ) THEN
    RAISE EXCEPTION 'Every order item must include product_id';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_items) AS item
    WHERE NULLIF(item ->> 'pricing_id', '') IS NULL
  ) THEN
    RAISE EXCEPTION 'Every order item must include pricing_id';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_items) AS item
    WHERE item ->> 'quantity' IS NULL
  ) THEN
    RAISE EXCEPTION 'Every order item must include quantity';
  END IF;


  -- ----------------------------------------------------------
  -- E) Store count + store acceptance validation.
  -- ----------------------------------------------------------

  SELECT COUNT(DISTINCT (item ->> 'store_id')::uuid)
  INTO v_store_count
  FROM jsonb_array_elements(p_items) AS item;

  IF v_store_count < 1 THEN
    RAISE EXCEPTION 'Order must contain at least one store';
  END IF;

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
  -- F) Validate every item and calculate subtotal.
  --
  -- IMPORTANT:
  -- Never trust client-side prices.
  -- ----------------------------------------------------------

  FOR v_item IN
    SELECT *
    FROM jsonb_array_elements(p_items)
  LOOP

    v_store_id := (v_item ->> 'store_id')::uuid;
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_pricing_id := (v_item ->> 'pricing_id')::uuid;

    v_offer_id :=
      NULLIF(v_item ->> 'offer_id', '')::uuid;

    v_qty := (v_item ->> 'quantity')::numeric;


    IF v_qty IS NULL OR v_qty <= 0 THEN
      RAISE EXCEPTION 'Invalid item quantity';
    END IF;


    -- Product.
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


    -- Pricing.
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


    -- Effective price.
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


    -- Selling method "value" means the requested value itself
    -- is the line total.
    IF v_product.selling_method = 'value' THEN
      v_subtotal := v_subtotal + v_qty;
    ELSE
      v_subtotal :=
        v_subtotal + (v_unit_price * v_qty);
    END IF;

  END LOOP;


  -- ----------------------------------------------------------
  -- G) Unified delivery fee.
  --
  -- 1-3 stores = 25
  -- 4 stores   = 30
  -- 5 stores   = 35
  -- 6 stores   = 40
  -- ----------------------------------------------------------

  IF v_store_count > 3 THEN
    v_delivery_fee :=
      25 + ((v_store_count - 3) * 5);
  END IF;


  -- ----------------------------------------------------------
  -- H) Create Unified Order.
  -- ----------------------------------------------------------

  INSERT INTO public.orders (
    customer_id,
    store_id,
    status,
    subtotal,
    delivery_fee,
    extra_fee,
    customer_notes,
    delivery_points,
    unified_order_date,
    unified_order_number,
    delivery_recipient_name,
    delivery_phone,
    delivery_governorate,
    delivery_city,
    delivery_area,
    delivery_building_number,
    delivery_apartment_number,
    delivery_address_details
  )
  VALUES (
    auth.uid(),
    NULL,
    'pending',
    v_subtotal,
    v_delivery_fee,
    0,
    p_customer_notes,
    0,
    v_order_date,
    private.next_unified_order_number(v_order_date),
    v_address.recipient_name,
    v_address.phone,
    v_address.governorate,
    v_address.city,
    v_address.area,
    v_address.building_number,
    v_address.apartment_number,
    v_address.address_details
  )
  RETURNING id, total
  INTO v_order_id, v_total;


  -- ----------------------------------------------------------
  -- I) Create Order Items.
  --
  -- Trigger validates again and snapshots:
  --   product_name
  --   unit_price
  -- ----------------------------------------------------------

  FOR v_item IN
    SELECT *
    FROM jsonb_array_elements(p_items)
  LOOP

    v_store_id := (v_item ->> 'store_id')::uuid;
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_pricing_id := (v_item ->> 'pricing_id')::uuid;

    v_offer_id :=
      NULLIF(v_item ->> 'offer_id', '')::uuid;

    v_qty := (v_item ->> 'quantity')::numeric;


    SELECT *
    INTO v_product
    FROM public.products
    WHERE id = v_product_id
      AND store_id = v_store_id
      AND is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'Product not found during order item creation';
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
      v_order_id,
      v_store_id,
      v_product_id,
      v_pricing_id,
      v_offer_id,
      v_product.name,
      v_product.price,
      v_qty,
      v_product.selling_method
    );

  END LOOP;


  -- ----------------------------------------------------------
  -- J) Create one payment record for the Unified Order.
  -- ----------------------------------------------------------

  INSERT INTO public.payments (
    order_id,
    payment_method,
    status,
    amount
  )
  VALUES (
    v_order_id,
    p_payment_method,
    'pending',
    v_total
  );


  RETURN v_order_id;

END;
$function$;


-- ------------------------------------------------------------
-- 4) Restrict RPC execution.
-- ------------------------------------------------------------

REVOKE ALL
ON FUNCTION public.create_unified_order(
  uuid,
  jsonb,
  public.payment_method,
  text
)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.create_unified_order(
  uuid,
  jsonb,
  public.payment_method,
  text
)
TO authenticated;


COMMIT;
