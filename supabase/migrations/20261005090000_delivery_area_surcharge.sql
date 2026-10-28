-- ============================================================
-- HENA - Delivery Area Surcharge
-- Adds a hidden 5 EGP area surcharge on top of the
-- existing delivery-fee calculation.
--
-- Existing delivery-fee logic is intentionally untouched.
-- ============================================================

CREATE OR REPLACE FUNCTION public.calculate_delivery_area_surcharge(
  p_area text
)
RETURNS numeric(12,2)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN trim(COALESCE(p_area, '')) IN (
      'الأندلس',
      '247'
    )
      THEN 0::numeric
    ELSE
      5::numeric
  END;
$function$;

REVOKE ALL ON FUNCTION public.calculate_delivery_area_surcharge(text)
FROM PUBLIC;

-- ------------------------------------------------------------
-- Add the area surcharge after the existing delivery fee
-- calculation in create_unified_order.
-- ------------------------------------------------------------

DO $block$
DECLARE
  v_definition text;
  v_old text;
  v_new text;
BEGIN
  SELECT pg_get_functiondef(
    'public.create_unified_order(uuid,jsonb,payment_method,text)'::regprocedure
  )
  INTO v_definition;

  IF position(
    'calculate_delivery_area_surcharge'
    IN v_definition
  ) <> 0 THEN
    RAISE EXCEPTION
      'create_unified_order already contains area surcharge logic';
  END IF;

  v_old :=
    E'SELECT public.calculate_delivery_fee(v_store_count)\n' ||
    E'  INTO v_delivery_fee;';

  v_new :=
    E'SELECT public.calculate_delivery_fee(v_store_count)\n' ||
    E'  INTO v_delivery_fee;\n\n' ||
    E'  v_delivery_fee :=\n' ||
    E'    v_delivery_fee +\n' ||
    E'    public.calculate_delivery_area_surcharge(v_address.area);';

  IF position(v_old IN v_definition) = 0 THEN
    RAISE EXCEPTION
      'Expected delivery-fee block was not found in create_unified_order';
  END IF;

  v_definition := replace(
    v_definition,
    v_old,
    v_new
  );

  EXECUTE v_definition;
END;
$block$;

-- ------------------------------------------------------------
-- Add the same area surcharge after the existing delivery fee
-- calculation in edit_unified_order.
-- ------------------------------------------------------------

DO $block$
DECLARE
  v_definition text;
  v_old text;
  v_new text;
BEGIN
  SELECT pg_get_functiondef(
    'public.edit_unified_order(uuid,jsonb)'::regprocedure
  )
  INTO v_definition;

  IF position(
    'calculate_delivery_area_surcharge'
    IN v_definition
  ) <> 0 THEN
    RAISE EXCEPTION
      'edit_unified_order already contains area surcharge logic';
  END IF;

  v_old :=
    E'SELECT public.calculate_delivery_fee(v_store_count)\n' ||
    E'  INTO v_delivery_fee;';

  v_new :=
    E'SELECT public.calculate_delivery_fee(v_store_count)\n' ||
    E'  INTO v_delivery_fee;\n\n' ||
    E'  v_delivery_fee :=\n' ||
    E'    v_delivery_fee +\n' ||
    E'    public.calculate_delivery_area_surcharge(v_order.delivery_area);';

  IF position(v_old IN v_definition) = 0 THEN
    RAISE EXCEPTION
      'Expected delivery-fee block was not found in edit_unified_order';
  END IF;

  v_definition := replace(
    v_definition,
    v_old,
    v_new
  );

  EXECUTE v_definition;
END;
$block$;

-- ------------------------------------------------------------
-- Verification
-- ------------------------------------------------------------

DO $verify$
DECLARE
  v_create text;
  v_edit text;
BEGIN
  SELECT pg_get_functiondef(
    'public.create_unified_order(uuid,jsonb,payment_method,text)'::regprocedure
  )
  INTO v_create;

  SELECT pg_get_functiondef(
    'public.edit_unified_order(uuid,jsonb)'::regprocedure
  )
  INTO v_edit;

  IF position(
    'public.calculate_delivery_area_surcharge(v_address.area)'
    IN v_create
  ) = 0 THEN
    RAISE EXCEPTION
      'Area surcharge is missing from create_unified_order';
  END IF;

  IF position(
    'public.calculate_delivery_area_surcharge(v_order.delivery_area)'
    IN v_edit
  ) = 0 THEN
    RAISE EXCEPTION
      'Area surcharge is missing from edit_unified_order';
  END IF;
END;
$verify$;