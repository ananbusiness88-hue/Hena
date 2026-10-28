-- ============================================================
-- HENA  Delivery Settings Control
-- Centralized delivery-fee configuration.
-- ============================================================

CREATE TABLE public.delivery_settings (
  id integer PRIMARY KEY DEFAULT 1,
  base_fee numeric(12,2) NOT NULL DEFAULT 25.00,
  included_stores integer NOT NULL DEFAULT 3,
  extra_store_fee numeric(12,2) NOT NULL DEFAULT 5.00,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT delivery_settings_singleton_check
    CHECK (id = 1),
  CONSTRAINT delivery_settings_base_fee_check
    CHECK (base_fee >= 0),
  CONSTRAINT delivery_settings_included_stores_check
    CHECK (included_stores >= 1),
  CONSTRAINT delivery_settings_extra_store_fee_check
    CHECK (extra_store_fee >= 0)
);

INSERT INTO public.delivery_settings (
  id,
  base_fee,
  included_stores,
  extra_store_fee
)
VALUES (
  1,
  25.00,
  3,
  5.00
);

ALTER TABLE public.delivery_settings
  ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.delivery_settings TO authenticated;

CREATE POLICY delivery_settings_select_authenticated
ON public.delivery_settings
FOR SELECT
TO authenticated
USING (true);

-- ============================================================
-- Read settings
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_delivery_settings()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_settings public.delivery_settings%ROWTYPE;
BEGIN
  SELECT *
  INTO v_settings
  FROM public.delivery_settings
  WHERE id = 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Delivery settings are not configured';
  END IF;

  RETURN jsonb_build_object(
    'base_fee', v_settings.base_fee,
    'included_stores', v_settings.included_stores,
    'extra_store_fee', v_settings.extra_store_fee,
    'updated_at', v_settings.updated_at
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_delivery_settings() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_delivery_settings() TO authenticated;

-- ============================================================
-- Server-side delivery fee calculation
-- ============================================================

CREATE OR REPLACE FUNCTION public.calculate_delivery_fee(
  p_store_count integer
)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
  SELECT CASE
    WHEN p_store_count <= 0 THEN 0::numeric
    WHEN p_store_count <= ds.included_stores
      THEN ds.base_fee
    ELSE
      ds.base_fee
      + (
          (p_store_count - ds.included_stores)
          * ds.extra_store_fee
        )
  END
  FROM public.delivery_settings ds
  WHERE ds.id = 1;
$function$;

REVOKE ALL ON FUNCTION public.calculate_delivery_fee(integer)
FROM PUBLIC;

-- ============================================================
-- Admin update
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_update_delivery_settings(
  p_base_fee numeric,
  p_included_stores integer,
  p_extra_store_fee numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_settings public.delivery_settings%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION
      'Only admins can update delivery settings';
  END IF;

  IF p_base_fee IS NULL OR p_base_fee < 0 THEN
    RAISE EXCEPTION 'Invalid base delivery fee';
  END IF;

  IF p_included_stores IS NULL OR p_included_stores < 1 THEN
    RAISE EXCEPTION 'Included store count must be at least 1';
  END IF;

  IF p_extra_store_fee IS NULL OR p_extra_store_fee < 0 THEN
    RAISE EXCEPTION 'Invalid extra store fee';
  END IF;

  UPDATE public.delivery_settings
  SET
    base_fee = p_base_fee,
    included_stores = p_included_stores,
    extra_store_fee = p_extra_store_fee,
    updated_at = now(),
    updated_by = auth.uid()
  WHERE id = 1
  RETURNING *
  INTO v_settings;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Delivery settings are not configured';
  END IF;

  RETURN jsonb_build_object(
    'base_fee', v_settings.base_fee,
    'included_stores', v_settings.included_stores,
    'extra_store_fee', v_settings.extra_store_fee,
    'updated_at', v_settings.updated_at
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_update_delivery_settings(
  numeric,
  integer,
  numeric
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_update_delivery_settings(
  numeric,
  integer,
  numeric
) TO authenticated;

-- ============================================================
-- Replace hard-coded delivery-fee logic in the authoritative
-- order functions without changing their business flow.
-- ============================================================

DO $block$
DECLARE
  v_function_oid oid;
  v_definition text;
  v_signature text;
  v_found integer := 0;

  v_old_declaration text :=
    'v_delivery_fee numeric(12,2) := 25;';

  v_old_formula text :=
    E'IF v_store_count > 3 THEN\n' ||
    E'    v_delivery_fee :=\n' ||
    E'      25 + ((v_store_count - 3) * 5);\n' ||
    E'  END IF;';

  v_new_formula text :=
    E'  SELECT public.calculate_delivery_fee(v_store_count)\n' ||
    E'  INTO v_delivery_fee;';
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

    IF position(v_old_declaration in v_definition) = 0 THEN
      RAISE EXCEPTION
        'Delivery declaration not found in %',
        v_signature;
    END IF;

    IF position(v_old_formula in v_definition) = 0 THEN
      RAISE EXCEPTION
        'Delivery formula not found in %',
        v_signature;
    END IF;

    v_definition :=
      replace(
        v_definition,
        v_old_declaration,
        'v_delivery_fee numeric(12,2) := 0;'
      );

    v_definition :=
      replace(
        v_definition,
        v_old_formula,
        v_new_formula
      );

    EXECUTE v_definition;
  END LOOP;

  IF v_found <> 2 THEN
    RAISE EXCEPTION
      'Expected 2 authoritative order functions, found %',
      v_found;
  END IF;
END;
$block$;

-- ============================================================
-- Verification-only assertions inside migration
-- ============================================================

DO $verify$
DECLARE
  v_create text;
  v_edit text;
BEGIN
  SELECT pg_get_functiondef(
    'public.create_unified_order(
      uuid,
      jsonb,
      payment_method,
      text
    )'::regprocedure
  )
  INTO v_create;

  SELECT pg_get_functiondef(
    'public.edit_unified_order(
      uuid,
      jsonb
    )'::regprocedure
  )
  INTO v_edit;

  IF v_create IS NULL THEN
    RAISE EXCEPTION 'create_unified_order definition is missing';
  END IF;

  IF v_edit IS NULL THEN
    RAISE EXCEPTION 'edit_unified_order definition is missing';
  END IF;

  IF position(
    '25 + ((v_store_count - 3) * 5)'
    in v_create
  ) <> 0 THEN
    RAISE EXCEPTION
      'Old delivery formula still exists in create_unified_order';
  END IF;

  IF position(
    '25 + ((v_store_count - 3) * 5)'
    in v_edit
  ) <> 0 THEN
    RAISE EXCEPTION
      'Old delivery formula still exists in edit_unified_order';
  END IF;

  IF position(
    'public.calculate_delivery_fee(v_store_count)'
    in v_create
  ) = 0 THEN
    RAISE EXCEPTION
      'create_unified_order is not using calculate_delivery_fee';
  END IF;

  IF position(
    'public.calculate_delivery_fee(v_store_count)'
    in v_edit
  ) = 0 THEN
    RAISE EXCEPTION
      'edit_unified_order is not using calculate_delivery_fee';
  END IF;
END;
$verify$;
