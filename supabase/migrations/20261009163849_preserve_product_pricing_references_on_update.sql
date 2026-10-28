CREATE OR REPLACE FUNCTION public.admin_update_product(
    p_product_id uuid, p_category_id uuid, p_name text,
    p_description text DEFAULT NULL::text, p_price numeric DEFAULT NULL::numeric,
    p_selling_method public.selling_method DEFAULT 'unit'::public.selling_method,
    p_selling_value numeric DEFAULT 1, p_is_active boolean DEFAULT true,
    p_pricing jsonb DEFAULT '[]'::jsonb
  )
  RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
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
    v_pricing_id uuid;
    v_requested_pricing_id uuid;
    v_matched_ids uuid[] := ARRAY[]::uuid[];
    v_match_count integer;
  BEGIN
    IF (SELECT auth.uid()) IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Admin privileges required'; END IF;
    IF trim(coalesce(p_name, '')) = '' THEN RAISE EXCEPTION 'Product name is required'; END IF;
    IF p_price IS NULL OR p_price <= 0 THEN RAISE EXCEPTION 'Product price must be greater than zero'; END IF;
    IF p_selling_value IS NULL OR p_selling_value <= 0 THEN RAISE EXCEPTION 'Selling value must be greater than zero'; END IF;
    IF p_pricing IS NULL OR jsonb_typeof(p_pricing) <> 'array' OR jsonb_array_length(p_pricing) = 0 THEN
      RAISE EXCEPTION 'At least one pricing option is required';
    END IF;

    SELECT p.store_id INTO v_store_id FROM public.products p WHERE p.id = p_product_id FOR UPDATE;
    IF v_store_id IS NULL THEN RAISE EXCEPTION 'Product not found or authorization failed'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.product_categories pc WHERE pc.id = p_category_id AND pc.store_id = v_store_id AND pc.is_active = true) THEN RAISE EXCEPTION 'Product category does not belong to the same active store'; END IF;

    UPDATE public.products SET
      category_id = p_category_id,
      name = trim(p_name),
      description = nullif(trim(coalesce(p_description, '')), ''),
      price = p_price,
      selling_method = p_selling_method,
      selling_value = p_selling_value,
      is_active = p_is_active,
      updated_at = now()
    WHERE id = p_product_id;

    FOR v_item IN SELECT value FROM jsonb_array_elements(p_pricing)
    LOOP
      v_pricing_type := (v_item ->> 'pricing_type')::public.product_pricing_type;
      v_unit_name := nullif(trim(v_item ->> 'unit_name'), '');
      v_quantity := nullif(v_item ->> 'quantity', '')::numeric;
      v_price := nullif(v_item ->> 'price', '')::numeric;
      v_fraction_value := nullif(v_item ->> 'fraction_value', '')::numeric;

      IF v_price IS NULL OR v_price <= 0 THEN RAISE EXCEPTION 'Pricing option price must be greater than zero'; END IF;
      IF v_pricing_type IN ('unit', 'weight') THEN
        IF v_unit_name IS NULL THEN RAISE EXCEPTION 'Unit name is required for unit/weight pricing'; END IF;
        IF v_quantity IS NULL OR v_quantity <= 0 THEN RAISE EXCEPTION 'Quantity must be greater than zero'; END IF;
        IF v_fraction_value IS NOT NULL THEN RAISE EXCEPTION 'Fraction value must be null for unit/weight pricing'; END IF;
      ELSIF v_pricing_type = 'value' THEN
        IF v_unit_name IS NOT NULL OR v_quantity IS NOT NULL OR v_fraction_value IS NOT NULL THEN
          RAISE EXCEPTION 'Value pricing cannot contain unit, quantity or fraction fields';
        END IF;
      ELSIF v_pricing_type = 'fraction' THEN
        IF v_fraction_value IS NULL OR v_fraction_value <= 0 OR v_fraction_value > 1 THEN
          RAISE EXCEPTION 'Fraction value must be greater than 0 and less than or equal to 1';
        END IF;
        IF v_unit_name IS NOT NULL OR v_quantity IS NOT NULL THEN RAISE EXCEPTION 'Fraction pricing cannot contain unit or quantity fields'; END IF;
      ELSE
        RAISE EXCEPTION 'Unsupported pricing type';
      END IF;

      v_requested_pricing_id := nullif(v_item ->> 'id', '')::uuid;
      v_pricing_id := NULL;

      IF v_requested_pricing_id IS NOT NULL THEN
        SELECT pp.id INTO v_pricing_id FROM public.product_pricing pp
        WHERE pp.id = v_requested_pricing_id AND pp.product_id = p_product_id
          AND NOT (pp.id = ANY(v_matched_ids))
        FOR UPDATE;
        IF v_pricing_id IS NULL THEN
          RAISE EXCEPTION 'Pricing option ID does not belong to this product or was repeated';
        END IF;
      ELSE
        SELECT pp.id INTO v_pricing_id
        FROM public.product_pricing pp
        WHERE pp.product_id = p_product_id AND pp.pricing_type = v_pricing_type
          AND pp.unit_name IS NOT DISTINCT FROM v_unit_name
          AND pp.quantity IS NOT DISTINCT FROM v_quantity
          AND pp.fraction_value IS NOT DISTINCT FROM v_fraction_value
          AND NOT (pp.id = ANY(v_matched_ids))
        ORDER BY
          CASE WHEN pp.sort_order = coalesce(nullif(v_item ->> 'sort_order', '')::integer, v_sort_order) THEN 0 ELSE 1 END,
          pp.sort_order, pp.created_at, pp.id
        LIMIT 1 FOR UPDATE;

        IF v_pricing_id IS NULL THEN
          SELECT count(*) INTO v_match_count FROM public.product_pricing pp
          WHERE pp.product_id = p_product_id AND pp.pricing_type = v_pricing_type
            AND pp.sort_order = coalesce(nullif(v_item ->> 'sort_order', '')::integer, v_sort_order)
            AND NOT (pp.id = ANY(v_matched_ids));

          IF v_match_count = 1 THEN
            SELECT pp.id INTO v_pricing_id FROM public.product_pricing pp
            WHERE pp.product_id = p_product_id AND pp.pricing_type = v_pricing_type
              AND pp.sort_order = coalesce(nullif(v_item ->> 'sort_order', '')::integer, v_sort_order)
              AND NOT (pp.id = ANY(v_matched_ids))
            LIMIT 1 FOR UPDATE;
          END IF;
        END IF;
      END IF;

      IF v_pricing_id IS NULL THEN
        INSERT INTO public.product_pricing
          (product_id, pricing_type, unit_name, quantity, price, fraction_value, is_active, sort_order)
        VALUES
          (p_product_id, v_pricing_type, v_unit_name, v_quantity, v_price, v_fraction_value,
           coalesce((v_item ->> 'is_active')::boolean, true), v_sort_order)
        RETURNING id INTO v_pricing_id;
      ELSE
        UPDATE public.product_pricing SET
          pricing_type = v_pricing_type, unit_name = v_unit_name, quantity = v_quantity,
          price = v_price, fraction_value = v_fraction_value,
          is_active = coalesce((v_item ->> 'is_active')::boolean, true),
          sort_order = v_sort_order, updated_at = now()
        WHERE id = v_pricing_id AND product_id = p_product_id
          AND (
            pricing_type IS DISTINCT FROM v_pricing_type OR unit_name IS DISTINCT FROM v_unit_name
            OR quantity IS DISTINCT FROM v_quantity OR price IS DISTINCT FROM v_price
            OR fraction_value IS DISTINCT FROM v_fraction_value
            OR is_active IS DISTINCT FROM coalesce((v_item ->> 'is_active')::boolean, true)
            OR sort_order IS DISTINCT FROM v_sort_order
          );
      END IF;

      v_matched_ids := array_append(v_matched_ids, v_pricing_id);
      v_sort_order := v_sort_order + 1;
    END LOOP;

    IF EXISTS (
      SELECT 1 FROM public.product_pricing pp
      WHERE pp.product_id = p_product_id AND NOT (pp.id = ANY(v_matched_ids))
        AND (
          EXISTS (SELECT 1 FROM public.offers o WHERE o.pricing_id = pp.id)
          OR EXISTS (SELECT 1 FROM public.order_items oi WHERE oi.pricing_id = pp.id)
        )
    ) THEN
      RAISE EXCEPTION 'A pricing option linked to an offer or historical order cannot be removed. Keep it and retry.';
    END IF;

    UPDATE public.product_pricing pp
    SET is_active = false, updated_at = now()
    WHERE pp.product_id = p_product_id
      AND pp.is_active = true
      AND NOT (pp.id = ANY(v_matched_ids))
      AND NOT EXISTS (SELECT 1 FROM public.offers o WHERE o.pricing_id = pp.id)
      AND NOT EXISTS (SELECT 1 FROM public.order_items oi WHERE oi.pricing_id = pp.id);

    RETURN p_product_id;
  END;
  $function$;

CREATE OR REPLACE FUNCTION public.store_owner_update_product(
    p_product_id uuid, p_category_id uuid, p_name text,
    p_description text DEFAULT NULL::text, p_price numeric DEFAULT NULL::numeric,
    p_selling_method public.selling_method DEFAULT 'unit'::public.selling_method,
    p_selling_value numeric DEFAULT 1, p_is_active boolean DEFAULT true,
    p_pricing jsonb DEFAULT '[]'::jsonb
  )
  RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
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
    v_pricing_id uuid;
    v_requested_pricing_id uuid;
    v_matched_ids uuid[] := ARRAY[]::uuid[];
    v_match_count integer;
  BEGIN
    IF (SELECT auth.uid()) IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    IF trim(coalesce(p_name, '')) = '' THEN RAISE EXCEPTION 'Product name is required'; END IF;
    IF p_price IS NULL OR p_price <= 0 THEN RAISE EXCEPTION 'Product price must be greater than zero'; END IF;
    IF p_selling_value IS NULL OR p_selling_value <= 0 THEN RAISE EXCEPTION 'Selling value must be greater than zero'; END IF;
    IF p_pricing IS NULL OR jsonb_typeof(p_pricing) <> 'array' OR jsonb_array_length(p_pricing) = 0 THEN
      RAISE EXCEPTION 'At least one pricing option is required';
    END IF;

    SELECT p.store_id INTO v_store_id FROM public.products p JOIN public.stores s ON s.id = p.store_id WHERE p.id = p_product_id AND s.owner_id = auth.uid() FOR UPDATE OF p;
    IF v_store_id IS NULL THEN RAISE EXCEPTION 'Product not found or authorization failed'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.stores s WHERE s.id = v_store_id AND s.is_active = true) THEN RAISE EXCEPTION 'Store is inactive or does not exist'; END IF;
       IF p_category_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.product_categories pc WHERE pc.id = p_category_id AND pc.store_id = v_store_id AND pc.is_active = true) THEN RAISE EXCEPTION 'Product category does not belong to the same active store'; END IF;

    UPDATE public.products SET
      category_id = p_category_id,
      name = trim(p_name),
      description = nullif(trim(coalesce(p_description, '')), ''),
      price = p_price,
      selling_method = p_selling_method,
      selling_value = p_selling_value,
      is_active = p_is_active,
      updated_at = now()
    WHERE id = p_product_id;

    FOR v_item IN SELECT value FROM jsonb_array_elements(p_pricing)
    LOOP
      v_pricing_type := (v_item ->> 'pricing_type')::public.product_pricing_type;
      v_unit_name := nullif(trim(v_item ->> 'unit_name'), '');
      v_quantity := nullif(v_item ->> 'quantity', '')::numeric;
      v_price := nullif(v_item ->> 'price', '')::numeric;
      v_fraction_value := nullif(v_item ->> 'fraction_value', '')::numeric;

      IF v_price IS NULL OR v_price <= 0 THEN RAISE EXCEPTION 'Pricing option price must be greater than zero'; END IF;
      IF v_pricing_type IN ('unit', 'weight') THEN
        IF v_unit_name IS NULL THEN RAISE EXCEPTION 'Unit name is required for unit/weight pricing'; END IF;
        IF v_quantity IS NULL OR v_quantity <= 0 THEN RAISE EXCEPTION 'Quantity must be greater than zero'; END IF;
        IF v_fraction_value IS NOT NULL THEN RAISE EXCEPTION 'Fraction value must be null for unit/weight pricing'; END IF;
      ELSIF v_pricing_type = 'value' THEN
        IF v_unit_name IS NOT NULL OR v_quantity IS NOT NULL OR v_fraction_value IS NOT NULL THEN
          RAISE EXCEPTION 'Value pricing cannot contain unit, quantity or fraction fields';
        END IF;
      ELSIF v_pricing_type = 'fraction' THEN
        IF v_fraction_value IS NULL OR v_fraction_value <= 0 OR v_fraction_value > 1 THEN
          RAISE EXCEPTION 'Fraction value must be greater than 0 and less than or equal to 1';
        END IF;
        IF v_unit_name IS NOT NULL OR v_quantity IS NOT NULL THEN RAISE EXCEPTION 'Fraction pricing cannot contain unit or quantity fields'; END IF;
      ELSE
        RAISE EXCEPTION 'Unsupported pricing type';
      END IF;

      v_requested_pricing_id := nullif(v_item ->> 'id', '')::uuid;
      v_pricing_id := NULL;

      IF v_requested_pricing_id IS NOT NULL THEN
        SELECT pp.id INTO v_pricing_id FROM public.product_pricing pp
        WHERE pp.id = v_requested_pricing_id AND pp.product_id = p_product_id
          AND NOT (pp.id = ANY(v_matched_ids))
        FOR UPDATE;
        IF v_pricing_id IS NULL THEN
          RAISE EXCEPTION 'Pricing option ID does not belong to this product or was repeated';
        END IF;
      ELSE
        SELECT pp.id INTO v_pricing_id
        FROM public.product_pricing pp
        WHERE pp.product_id = p_product_id AND pp.pricing_type = v_pricing_type
          AND pp.unit_name IS NOT DISTINCT FROM v_unit_name
          AND pp.quantity IS NOT DISTINCT FROM v_quantity
          AND pp.fraction_value IS NOT DISTINCT FROM v_fraction_value
          AND NOT (pp.id = ANY(v_matched_ids))
        ORDER BY
          CASE WHEN pp.sort_order = coalesce(nullif(v_item ->> 'sort_order', '')::integer, v_sort_order) THEN 0 ELSE 1 END,
          pp.sort_order, pp.created_at, pp.id
        LIMIT 1 FOR UPDATE;

        IF v_pricing_id IS NULL THEN
          SELECT count(*) INTO v_match_count FROM public.product_pricing pp
          WHERE pp.product_id = p_product_id AND pp.pricing_type = v_pricing_type
            AND pp.sort_order = coalesce(nullif(v_item ->> 'sort_order', '')::integer, v_sort_order)
            AND NOT (pp.id = ANY(v_matched_ids));

          IF v_match_count = 1 THEN
            SELECT pp.id INTO v_pricing_id FROM public.product_pricing pp
            WHERE pp.product_id = p_product_id AND pp.pricing_type = v_pricing_type
              AND pp.sort_order = coalesce(nullif(v_item ->> 'sort_order', '')::integer, v_sort_order)
              AND NOT (pp.id = ANY(v_matched_ids))
            LIMIT 1 FOR UPDATE;
          END IF;
        END IF;
      END IF;

      IF v_pricing_id IS NULL THEN
        INSERT INTO public.product_pricing
          (product_id, pricing_type, unit_name, quantity, price, fraction_value, is_active, sort_order)
        VALUES
          (p_product_id, v_pricing_type, v_unit_name, v_quantity, v_price, v_fraction_value,
           coalesce((v_item ->> 'is_active')::boolean, true), v_sort_order)
        RETURNING id INTO v_pricing_id;
      ELSE
        UPDATE public.product_pricing SET
          pricing_type = v_pricing_type, unit_name = v_unit_name, quantity = v_quantity,
          price = v_price, fraction_value = v_fraction_value,
          is_active = coalesce((v_item ->> 'is_active')::boolean, true),
          sort_order = v_sort_order, updated_at = now()
        WHERE id = v_pricing_id AND product_id = p_product_id
          AND (
            pricing_type IS DISTINCT FROM v_pricing_type OR unit_name IS DISTINCT FROM v_unit_name
            OR quantity IS DISTINCT FROM v_quantity OR price IS DISTINCT FROM v_price
            OR fraction_value IS DISTINCT FROM v_fraction_value
            OR is_active IS DISTINCT FROM coalesce((v_item ->> 'is_active')::boolean, true)
            OR sort_order IS DISTINCT FROM v_sort_order
          );
      END IF;

      v_matched_ids := array_append(v_matched_ids, v_pricing_id);
      v_sort_order := v_sort_order + 1;
    END LOOP;

    IF EXISTS (
      SELECT 1 FROM public.product_pricing pp
      WHERE pp.product_id = p_product_id AND NOT (pp.id = ANY(v_matched_ids))
        AND (
          EXISTS (SELECT 1 FROM public.offers o WHERE o.pricing_id = pp.id)
          OR EXISTS (SELECT 1 FROM public.order_items oi WHERE oi.pricing_id = pp.id)
        )
    ) THEN
      RAISE EXCEPTION 'A pricing option linked to an offer or historical order cannot be removed. Keep it and retry.';
    END IF;

    UPDATE public.product_pricing pp
    SET is_active = false, updated_at = now()
    WHERE pp.product_id = p_product_id
      AND pp.is_active = true
      AND NOT (pp.id = ANY(v_matched_ids))
      AND NOT EXISTS (SELECT 1 FROM public.offers o WHERE o.pricing_id = pp.id)
      AND NOT EXISTS (SELECT 1 FROM public.order_items oi WHERE oi.pricing_id = pp.id);

    RETURN p_product_id;
  END;
  $function$;;
