-- ============================================================
-- STORE OWNER PRODUCT MANAGEMENT
-- Allows Store Owners to manage products only in their own stores.
-- Admin RPCs remain restricted to Admin.
-- ============================================================

CREATE OR REPLACE FUNCTION public.store_owner_create_product(
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
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.stores s
    WHERE s.id = p_store_id
      AND s.owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Store owner privileges required';
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


CREATE OR REPLACE FUNCTION public.store_owner_update_product(
  p_product_id uuid,
  p_category_id uuid,
  p_name text,
  p_description text DEFAULT NULL,
  p_price numeric DEFAULT NULL,
  p_selling_method public.selling_method DEFAULT 'unit',
  p_selling_value numeric DEFAULT 1,
  p_is_active boolean DEFAULT true,
  p_pricing jsonb DEFAULT '[]'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_store_id uuid;
  v_item jsonb;
  v_pricing_type public.product_pricing_type;
  v_fraction_value numeric;
  v_quantity numeric;
  v_price numeric;
  v_unit_name text;
  v_sort_order integer := 0;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF trim(coalesce(p_name, '')) = '' THEN
    RAISE EXCEPTION 'Product name is required';
  END IF;

  IF p_price IS NULL OR p_price <= 0 THEN
    RAISE EXCEPTION 'Product price must be greater than zero';
  END IF;

  IF p_selling_value IS NULL OR p_selling_value <= 0 THEN
    RAISE EXCEPTION 'Selling value must be greater than zero';
  END IF;

  IF p_pricing IS NULL
     OR jsonb_typeof(p_pricing) <> 'array'
     OR jsonb_array_length(p_pricing) = 0 THEN
    RAISE EXCEPTION 'At least one pricing option is required';
  END IF;

  SELECT p.store_id
    INTO v_store_id
  FROM public.products p
  JOIN public.stores s
    ON s.id = p.store_id
  WHERE p.id = p_product_id
    AND s.owner_id = auth.uid()
  FOR UPDATE OF p;

  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'Product not found or store owner privileges required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.stores s
    WHERE s.id = v_store_id
      AND s.is_active = true
  ) THEN
    RAISE EXCEPTION 'Store is inactive or does not exist';
  END IF;

  IF p_category_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM public.product_categories pc
       WHERE pc.id = p_category_id
         AND pc.store_id = v_store_id
         AND pc.is_active = true
     )
  THEN
    RAISE EXCEPTION 'Product category does not belong to the same active store';
  END IF;

  UPDATE public.products
  SET
    category_id = p_category_id,
    name = trim(p_name),
    description = nullif(trim(coalesce(p_description, '')), ''),
    price = p_price,
    selling_method = p_selling_method,
    selling_value = p_selling_value,
    is_active = p_is_active,
    updated_at = now()
  WHERE id = p_product_id;

  DELETE FROM public.product_pricing
  WHERE product_id = p_product_id;

  FOR v_item IN
    SELECT value
    FROM jsonb_array_elements(p_pricing)
  LOOP
    v_pricing_type :=
      (v_item ->> 'pricing_type')::public.product_pricing_type;

    v_unit_name := nullif(trim(v_item ->> 'unit_name'), '');
    v_quantity := nullif(v_item ->> 'quantity', '')::numeric;
    v_price := nullif(v_item ->> 'price', '')::numeric;
    v_fraction_value :=
      nullif(v_item ->> 'fraction_value', '')::numeric;

    IF v_price IS NULL OR v_price <= 0 THEN
      RAISE EXCEPTION 'Pricing option price must be greater than zero';
    END IF;

    IF v_pricing_type IN ('unit', 'weight') THEN

      IF v_unit_name IS NULL THEN
        RAISE EXCEPTION 'Unit name is required for unit/weight pricing';
      END IF;

      IF v_quantity IS NULL OR v_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero';
      END IF;

      IF v_fraction_value IS NOT NULL THEN
        RAISE EXCEPTION 'Fraction value must be null for unit/weight pricing';
      END IF;

    ELSIF v_pricing_type = 'value' THEN

      IF v_unit_name IS NOT NULL
         OR v_quantity IS NOT NULL
         OR v_fraction_value IS NOT NULL THEN
        RAISE EXCEPTION 'Value pricing cannot contain unit, quantity or fraction fields';
      END IF;

    ELSIF v_pricing_type = 'fraction' THEN

      IF v_fraction_value IS NULL
         OR v_fraction_value <= 0
         OR v_fraction_value > 1 THEN
        RAISE EXCEPTION 'Fraction value must be greater than 0 and less than or equal to 1';
      END IF;

      IF v_unit_name IS NOT NULL
         OR v_quantity IS NOT NULL THEN
        RAISE EXCEPTION 'Fraction pricing cannot contain unit or quantity fields';
      END IF;

    ELSE
      RAISE EXCEPTION 'Unsupported pricing type';
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
      p_product_id,
      v_pricing_type,
      v_unit_name,
      v_quantity,
      v_price,
      v_fraction_value,
      COALESCE((v_item ->> 'is_active')::boolean, true),
      v_sort_order
    );

    v_sort_order := v_sort_order + 1;
  END LOOP;

  RETURN p_product_id;
END;
$function$;


REVOKE ALL ON FUNCTION public.store_owner_create_product(
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

GRANT EXECUTE ON FUNCTION public.store_owner_create_product(
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


REVOKE ALL ON FUNCTION public.store_owner_update_product(
  uuid,
  uuid,
  text,
  text,
  numeric,
  public.selling_method,
  numeric,
  boolean,
  jsonb
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.store_owner_update_product(
  uuid,
  uuid,
  text,
  text,
  numeric,
  public.selling_method,
  numeric,
  boolean,
  jsonb
) TO authenticated;
