DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'selling_method'
  ) THEN
    CREATE TYPE public.selling_method AS ENUM (
      'unit',
      'value',
      'fraction',
      'weight'
    );
  END IF;
END
$do$;

-- ============================================================================
-- ADMIN CREATE PRODUCT
-- Atomic creation of a product and its pricing options.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_create_product(
  p_store_id uuid,
  p_name text,
  p_price numeric(12,2),
  p_selling_method public.selling_method,
  p_category_id uuid DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_image_url text DEFAULT NULL,
  p_selling_value numeric(12,3) DEFAULT 1,
  p_is_active boolean DEFAULT true,
  p_pricing jsonb DEFAULT '[]'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_product_id uuid;
  v_pricing jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin privileges required';
  END IF;

  IF p_store_id IS NULL THEN
    RAISE EXCEPTION 'Store is required';
  END IF;

  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Product name is required';
  END IF;

  IF p_price IS NULL OR p_price <= 0 THEN
    RAISE EXCEPTION 'Product price must be greater than zero';
  END IF;

  IF p_selling_value IS NULL OR p_selling_value <= 0 THEN
    RAISE EXCEPTION 'Selling value must be greater than zero';
  END IF;

  IF jsonb_typeof(p_pricing) <> 'array' THEN
    RAISE EXCEPTION 'Pricing options must be a JSON array';
  END IF;

  IF jsonb_array_length(p_pricing) = 0 THEN
    RAISE EXCEPTION 'At least one pricing option is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.stores s
    WHERE s.id = p_store_id
      AND s.is_active = true
  ) THEN
    RAISE EXCEPTION 'Store is inactive or does not exist';
  END IF;

  IF p_category_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM public.product_categories pc
       WHERE pc.id = p_category_id
         AND pc.store_id = p_store_id
         AND pc.is_active = true
     )
  THEN
    RAISE EXCEPTION 'Product category does not belong to the selected store';
  END IF;

  INSERT INTO public.products (
    store_id,
    name,
    description,
    image_url,
    price,
    selling_method,
    selling_value,
    is_active,
    category_id
  )
  VALUES (
    p_store_id,
    btrim(p_name),
    NULLIF(btrim(p_description), ''),
    NULLIF(btrim(p_image_url), ''),
    p_price,
    p_selling_method,
    p_selling_value,
    p_is_active,
    p_category_id
  )
  RETURNING id INTO v_product_id;

  FOR v_pricing IN
    SELECT value
    FROM jsonb_array_elements(p_pricing)
  LOOP
    IF NOT (v_pricing ? 'pricing_type') THEN
      RAISE EXCEPTION 'Each pricing option requires pricing_type';
    END IF;

    IF NOT (v_pricing ? 'price') THEN
      RAISE EXCEPTION 'Each pricing option requires price';
    END IF;

    INSERT INTO public.product_pricing (
      product_id,
      pricing_type,
      unit_name,
      quantity,
      price,
      fraction_value,
      is_active,
      sort_order
    )
    VALUES (
      v_product_id,
      (v_pricing ->> 'pricing_type')::public.product_pricing_type,
      NULLIF(btrim(v_pricing ->> 'unit_name'), ''),
      NULLIF(v_pricing ->> 'quantity', '')::numeric,
      (v_pricing ->> 'price')::numeric,
      NULLIF(v_pricing ->> 'fraction_value', '')::numeric,
      COALESCE((v_pricing ->> 'is_active')::boolean, true),
      COALESCE((v_pricing ->> 'sort_order')::integer, 0)
    );
  END LOOP;

  RETURN v_product_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_create_product(
  uuid,
  text,
  numeric,
  public.selling_method,
  uuid,
  text,
  text,
  numeric,
  boolean,
  jsonb
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_create_product(
  uuid,
  text,
  numeric,
  public.selling_method,
  uuid,
  text,
  text,
  numeric,
  boolean,
  jsonb
) TO authenticated;
