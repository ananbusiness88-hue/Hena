-- ============================================================
-- HENA - Additional product fee
--
-- A product may carry an extra per-unit surcharge that is added
-- on top of its normal price.
--
-- Semantics
--   products.additional_fee      : per-unit surcharge (>= 0)
--   order_items.additional_fee   : snapshot taken when the order
--                                  was created, so historical orders
--                                  never change when the product is
--                                  edited later
--   order_items.item_total       : generated column, now
--                                  (base line total + surcharge)
--
-- The fee is added exactly once: the order subtotal is the sum of
-- the item totals, and the item total already contains the
-- surcharge.
-- ============================================================

-- ------------------------------------------------------------
-- 1) Schema.
-- ------------------------------------------------------------

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS additional_fee numeric(12,2) NOT NULL DEFAULT 0;

ALTER TABLE public.products
  DROP CONSTRAINT IF EXISTS products_additional_fee_check;

ALTER TABLE public.products
  ADD CONSTRAINT products_additional_fee_check
  CHECK (additional_fee >= 0);

ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS additional_fee numeric(12,2) NOT NULL DEFAULT 0;

ALTER TABLE public.order_items
  DROP CONSTRAINT IF EXISTS order_items_additional_fee_check;

ALTER TABLE public.order_items
  ADD CONSTRAINT order_items_additional_fee_check
  CHECK (additional_fee >= 0);

-- ------------------------------------------------------------
-- 2) item_total now includes the surcharge.
--
-- The column is regenerated so that it is always derived from
-- unit_price, quantity and additional_fee. Existing rows keep
-- their previous totals because additional_fee defaults to 0.
-- ------------------------------------------------------------

ALTER TABLE public.order_items
  DROP COLUMN IF EXISTS item_total;

ALTER TABLE public.order_items
  ADD COLUMN item_total numeric(12,2) GENERATED ALWAYS AS (
    (
      CASE
        WHEN "selling_method" = 'value'::"public"."selling_method"
          THEN "quantity"
        ELSE ("unit_price" * "quantity")
      END
    )
    + ("additional_fee" * "quantity")
  ) STORED;

-- ------------------------------------------------------------
-- 3) Snapshot the fee onto every order item.
--
-- The trigger already snapshots product_name and unit_price, so
-- the surcharge is snapshotted in exactly the same place.
-- ------------------------------------------------------------

DO $block$
DECLARE
  v_definition text;
  v_anchor text;
  v_insert text;
BEGIN
  SELECT pg_get_functiondef(
    'public.validate_order_item()'::regprocedure
  )
  INTO v_definition;

  IF v_definition IS NULL THEN
    RAISE EXCEPTION 'validate_order_item() was not found';
  END IF;

  IF position('additional_fee' IN v_definition) <> 0 THEN
    RAISE EXCEPTION
      'validate_order_item already contains additional_fee logic';
  END IF;

  v_anchor := E'  NEW.product_name := v_product.name;';

  v_insert :=
    E'  NEW.additional_fee := v_product.additional_fee;\n' ||
    v_anchor;

  IF position(v_anchor IN v_definition) = 0 THEN
    RAISE EXCEPTION
      'Expected product_name snapshot was not found in validate_order_item';
  END IF;

  v_definition := replace(v_definition, v_anchor, v_insert);

  EXECUTE v_definition;
END;
$block$;

-- ------------------------------------------------------------
-- 4) The order subtotal must include the surcharge.
--
-- create_unified_order and edit_unified_order accumulate the
-- subtotal inside their item loop. The patterns below are
-- whitespace tolerant because the two functions format the same
-- statement differently.
-- ------------------------------------------------------------

DO $block$
DECLARE
  v_function_oid oid;
  v_signature text;
  v_definition text;
  v_before text;
  v_found integer := 0;
BEGIN
  FOR v_function_oid IN
    SELECT p.oid
    FROM pg_proc p
    JOIN pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.oid::regprocedure::text IN (
        'create_unified_order(uuid,jsonb,payment_method,text)',
        'edit_unified_order(uuid,jsonb)'
      )
    ORDER BY p.oid::regprocedure::text
  LOOP
    v_found := v_found + 1;
    v_signature := v_function_oid::regprocedure::text;
    v_definition := pg_get_functiondef(v_function_oid);
    v_before := v_definition;

    IF position('additional_fee' IN v_definition) <> 0 THEN
      RAISE EXCEPTION
        '% already contains additional_fee logic',
        v_signature;
    END IF;

    -- Normal (unit / weight / fraction) line.
    v_definition := regexp_replace(
      v_definition,
      'v_subtotal\s*:=\s*v_subtotal\s*\+\s*\(v_unit_price\s*\*\s*v_qty\);',
      'v_subtotal := v_subtotal + (v_unit_price * v_qty) '
      '+ (v_product.additional_fee * v_qty);',
      'g'
    );

    -- "value" selling method: the requested value is the line total.
    v_definition := regexp_replace(
      v_definition,
      'v_subtotal\s*:=\s*v_subtotal\s*\+\s*v_qty;',
      'v_subtotal := v_subtotal + v_qty '
      '+ (v_product.additional_fee * v_qty);',
      'g'
    );

    IF v_definition = v_before THEN
      RAISE EXCEPTION
        'Subtotal accumulation was not found in %',
        v_signature;
    END IF;

    EXECUTE v_definition;
  END LOOP;

  IF v_found <> 2 THEN
    RAISE EXCEPTION
      'Expected 2 authoritative order functions, found %',
      v_found;
  END IF;
END;
$block$;

-- ------------------------------------------------------------
-- 5) Configure the fee for a product.
--
-- Store owners may only change the fee of products in their own
-- store; admins may change any product. The value is validated
-- on the server so a negative or invalid fee can never be stored.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_product_additional_fee(
  p_product_id uuid,
  p_additional_fee numeric(12,2)
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_fee numeric(12,2);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_product_id IS NULL THEN
    RAISE EXCEPTION 'Product is required';
  END IF;

  IF p_additional_fee IS NULL OR p_additional_fee < 0 THEN
    RAISE EXCEPTION 'Additional fee must be zero or greater';
  END IF;

  IF NOT public.is_admin()
     AND NOT EXISTS (
       SELECT 1
       FROM public.products p
       JOIN public.stores s
         ON s.id = p.store_id
       WHERE p.id = p_product_id
         AND s.owner_id = auth.uid()
     )
  THEN
    RAISE EXCEPTION
      'You are not allowed to change the additional fee of this product';
  END IF;

  UPDATE public.products
  SET additional_fee = p_additional_fee,
      updated_at = now()
  WHERE id = p_product_id
  RETURNING additional_fee INTO v_fee;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product not found';
  END IF;

  RETURN v_fee;
END;
$function$;

REVOKE ALL ON FUNCTION public.set_product_additional_fee(uuid, numeric)
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.set_product_additional_fee(uuid, numeric)
TO authenticated;

-- ------------------------------------------------------------
-- 6) Verification.
-- ------------------------------------------------------------

DO $verify$
DECLARE
  v_definition text;
  v_expression text;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'products'
      AND column_name = 'additional_fee'
  ) THEN
    RAISE EXCEPTION 'products.additional_fee is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'order_items'
      AND column_name = 'additional_fee'
  ) THEN
    RAISE EXCEPTION 'order_items.additional_fee is missing';
  END IF;

  SELECT pg_get_expr(adbin, adrelid)
  INTO v_expression
  FROM pg_attrdef
  WHERE adrelid = 'public.order_items'::regclass
    AND adnum = (
      SELECT attnum
      FROM pg_attribute
      WHERE attrelid = 'public.order_items'::regclass
        AND attname = 'item_total'
    );

  IF v_expression IS NULL THEN
    RAISE EXCEPTION 'order_items.item_total is missing';
  END IF;

  IF position('additional_fee' IN v_expression) = 0 THEN
    RAISE EXCEPTION
      'order_items.item_total does not include additional_fee';
  END IF;

  SELECT pg_get_functiondef(
    'public.validate_order_item()'::regprocedure
  )
  INTO v_definition;

  IF position('additional_fee' IN v_definition) = 0 THEN
    RAISE EXCEPTION
      'validate_order_item does not snapshot additional_fee';
  END IF;

  SELECT pg_get_functiondef(
    'public.create_unified_order(uuid,jsonb,payment_method,text)'::regprocedure
  )
  INTO v_definition;

  IF position('additional_fee' IN v_definition) = 0 THEN
    RAISE EXCEPTION
      'create_unified_order does not include additional_fee';
  END IF;

  SELECT pg_get_functiondef(
    'public.edit_unified_order(uuid,jsonb)'::regprocedure
  )
  INTO v_definition;

  IF position('additional_fee' IN v_definition) = 0 THEN
    RAISE EXCEPTION
      'edit_unified_order does not include additional_fee';
  END IF;
END;
$verify$;
