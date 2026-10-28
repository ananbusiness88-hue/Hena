BEGIN;

-- HENA FOUNDATION HARDENING
-- Local development schema. Keeps the existing database architecture and
-- prepares it for the Master Workflow: dual-mode accounts, multi-store orders,
-- unified order numbers, store availability, and controlled store-part updates.

-- 1) Store availability lives in the existing store_settings table.
INSERT INTO public.store_settings (store_id, accepts_orders)
SELECT s.id, true
FROM public.stores s
ON CONFLICT (store_id) DO NOTHING;

ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS store_settings_select_public ON public.store_settings;
CREATE POLICY store_settings_select_public
ON public.store_settings FOR SELECT TO anon, authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.stores s
    WHERE s.id = store_settings.store_id
      AND s.is_active = true
  )
);

DROP POLICY IF EXISTS store_settings_select_owner ON public.store_settings;
CREATE POLICY store_settings_select_owner
ON public.store_settings FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.id = store_settings.store_id
      AND s.owner_id = auth.uid()
  )
);

DROP POLICY IF EXISTS store_settings_update_owner ON public.store_settings;
CREATE POLICY store_settings_update_owner
ON public.store_settings FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.id = store_settings.store_id
      AND s.owner_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.id = store_settings.store_id
      AND s.owner_id = auth.uid()
  )
);

DROP POLICY IF EXISTS store_settings_admin ON public.store_settings;
CREATE POLICY store_settings_admin
ON public.store_settings FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE OR REPLACE FUNCTION public.store_owner_set_accepts_orders(
  p_store_id uuid,
  p_accepts_orders boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  IF public.current_user_role() NOT IN ('store_owner', 'admin') THEN
    RAISE EXCEPTION 'Store owner privileges required';
  END IF;

  UPDATE public.store_settings ss
  SET accepts_orders = p_accepts_orders,
      updated_at = now()
  WHERE ss.store_id = p_store_id
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = ss.store_id
          AND s.owner_id = auth.uid()
      )
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Store not found or access denied';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.store_owner_set_accepts_orders(uuid, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.store_owner_set_accepts_orders(uuid, boolean) TO authenticated;

-- 2) Dual-mode account foundation.
-- addresses already reference profiles(id) through user_id in the current schema.
-- orders must not be constrained to role='customer'.
ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_customer_role_fk;

ALTER TABLE public.orders
  DROP COLUMN IF EXISTS customer_role;

-- 3) Make the commercial order genuinely multi-store capable.
-- Remove the dependent FK first, then remove the old composite unique key.

ALTER TABLE public.order_items
  DROP CONSTRAINT IF EXISTS order_items_order_store_fk;

ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_id_store_id_key;

ALTER TABLE public.orders
  ALTER COLUMN store_id DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'order_items_order_fk'
      AND conrelid = 'public.order_items'::regclass
  ) THEN
    ALTER TABLE public.order_items
      ADD CONSTRAINT order_items_order_fk
      FOREIGN KEY (order_id)
      REFERENCES public.orders(id)
      ON DELETE RESTRICT;
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_order_items_order_id
  ON public.order_items(order_id);

-- 4) Store-owner order visibility is through Store Portions, not orders.store_id.
DROP POLICY IF EXISTS orders_select_store_owner ON public.orders;
CREATE POLICY orders_select_store_owner
ON public.orders FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.order_store_parts osp
    JOIN public.stores s ON s.id = osp.store_id
    WHERE osp.order_id = orders.id
      AND s.owner_id = auth.uid()
  )
);

DROP POLICY IF EXISTS orders_update_store_owner ON public.orders;

DROP POLICY IF EXISTS order_items_select_store_owner ON public.order_items;
CREATE POLICY order_items_select_store_owner
ON public.order_items FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.stores s
    WHERE s.id = order_items.store_id
      AND s.owner_id = auth.uid()
  )
);

-- 5) Unified commercial order number.
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS private.daily_order_sequences (
  order_date date PRIMARY KEY,
  last_value integer NOT NULL CHECK (last_value >= 0)
);

CREATE OR REPLACE FUNCTION private.next_unified_order_number(p_order_date date)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public
AS $$
DECLARE
  v_sequence integer;
BEGIN
  INSERT INTO private.daily_order_sequences (order_date, last_value)
  VALUES (p_order_date, 1)
  ON CONFLICT (order_date)
  DO UPDATE
  SET last_value = private.daily_order_sequences.last_value + 1
  RETURNING last_value INTO v_sequence;

  RETURN 'SD' || to_char(p_order_date, 'DDMM') || lpad(v_sequence::text, 3, '0');
END;
$$;

REVOKE ALL ON FUNCTION private.next_unified_order_number(date) FROM PUBLIC, anon, authenticated;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS unified_order_date date;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS unified_order_number text;

-- Temporarily disable legacy order mutation protection during migration backfill.
-- The migration itself must update existing orders.
DROP TRIGGER IF EXISTS trigger_protect_order_mutations ON public.orders;

WITH numbered AS (
  SELECT
    id,
    ((created_at AT TIME ZONE 'Africa/Cairo')::date) AS order_date,
    row_number() OVER (
      PARTITION BY ((created_at AT TIME ZONE 'Africa/Cairo')::date)
      ORDER BY created_at, id
    ) AS seq
  FROM public.orders
)
UPDATE public.orders o
SET
  unified_order_date = n.order_date,
  unified_order_number = 'SD'
    || to_char(n.order_date, 'DDMM')
    || lpad(n.seq::text, 3, '0')
FROM numbered n
WHERE o.id = n.id
  AND (o.unified_order_date IS NULL OR o.unified_order_number IS NULL);

INSERT INTO private.daily_order_sequences (order_date, last_value)
SELECT
  unified_order_date,
  max((substring(unified_order_number from 7))::integer)
FROM public.orders
WHERE unified_order_date IS NOT NULL
  AND unified_order_number IS NOT NULL
GROUP BY unified_order_date
ON CONFLICT (order_date)
DO UPDATE SET last_value = GREATEST(
  private.daily_order_sequences.last_value,
  EXCLUDED.last_value
);

ALTER TABLE public.orders
  ALTER COLUMN unified_order_date SET NOT NULL;

ALTER TABLE public.orders
  ALTER COLUMN unified_order_number SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_unified_number_per_day
  ON public.orders(unified_order_date, unified_order_number);

CREATE INDEX IF NOT EXISTS idx_orders_unified_order_number
  ON public.orders(unified_order_number);

-- 6) Rebuild legacy single-store RPC around the same foundation.
CREATE OR REPLACE FUNCTION public.create_order(
  p_store_id uuid,
  p_address_id uuid,
  p_items jsonb,
  p_customer_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_order_id uuid;
  v_address public.addresses%ROWTYPE;
  v_item jsonb;
  v_product public.products%ROWTYPE;
  v_qty numeric;
  v_subtotal numeric(12,2) := 0;
  v_order_date date := ((now() AT TIME ZONE 'Africa/Cairo')::date);
BEGIN
  IF public.current_user_role() NOT IN ('customer', 'store_owner') THEN
    RAISE EXCEPTION 'Only customer or store_owner accounts can create customer orders';
  END IF;

  IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Order must contain at least one item';
  END IF;

  SELECT *
  INTO v_address
  FROM public.addresses
  WHERE id = p_address_id
    AND user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Delivery address not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.stores s
    JOIN public.store_settings ss ON ss.store_id = s.id
    WHERE s.id = p_store_id
      AND s.is_active = true
      AND ss.accepts_orders = true
  ) THEN
    RAISE EXCEPTION 'Store not found, inactive, or not accepting delivery orders';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_qty := (v_item ->> 'quantity')::numeric;

    IF v_qty IS NULL OR v_qty <= 0 THEN
      RAISE EXCEPTION 'Invalid item quantity';
    END IF;

    SELECT *
    INTO v_product
    FROM public.products
    WHERE id = (v_item ->> 'product_id')::uuid
      AND store_id = p_store_id
      AND is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product not found, inactive, or belongs to another store';
    END IF;

    IF v_product.selling_method = 'value' THEN
      v_subtotal := v_subtotal + v_qty;
    ELSE
      v_subtotal := v_subtotal + (v_product.price * v_qty);
    END IF;
  END LOOP;

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
    p_store_id,
    'pending',
    v_subtotal,
    25,
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
  RETURNING id INTO v_order_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_qty := (v_item ->> 'quantity')::numeric;

    SELECT *
    INTO v_product
    FROM public.products
    WHERE id = (v_item ->> 'product_id')::uuid
      AND store_id = p_store_id
      AND is_active = true;

    INSERT INTO public.order_items (
      order_id,
      store_id,
      product_id,
      product_name,
      unit_price,
      quantity,
      selling_method
    )
    VALUES (
      v_order_id,
      p_store_id,
      v_product.id,
      v_product.name,
      v_product.price,
      v_qty,
      v_product.selling_method
    );
  END LOOP;

  RETURN v_order_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_order(uuid, uuid, jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_order(uuid, uuid, jsonb, text) TO authenticated;

-- 7) Authoritative multi-store order creation RPC.
CREATE OR REPLACE FUNCTION public.create_unified_order(
  p_address_id uuid,
  p_items jsonb,
  p_customer_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_order_id uuid;
  v_address public.addresses%ROWTYPE;
  v_item jsonb;
  v_product public.products%ROWTYPE;
  v_store_id uuid;
  v_qty numeric;
  v_subtotal numeric(12,2) := 0;
  v_store_count integer := 0;
  v_delivery_fee numeric(12,2) := 25;
  v_order_date date := ((now() AT TIME ZONE 'Africa/Cairo')::date);
BEGIN
  IF public.current_user_role() NOT IN ('customer', 'store_owner') THEN
    RAISE EXCEPTION 'Only customer or store_owner accounts can create customer orders';
  END IF;

  IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Order must contain at least one item';
  END IF;

  SELECT *
  INTO v_address
  FROM public.addresses
  WHERE id = p_address_id
    AND user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Delivery address not found';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_items) item
    WHERE NULLIF(item ->> 'store_id', '') IS NULL
  ) THEN
    RAISE EXCEPTION 'Every order item must include store_id';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_items) item
    WHERE NULLIF(item ->> 'product_id', '') IS NULL
  ) THEN
    RAISE EXCEPTION 'Every order item must include product_id';
  END IF;

  SELECT count(DISTINCT (item ->> 'store_id')::uuid)
  INTO v_store_count
  FROM jsonb_array_elements(p_items) item;

  IF v_store_count < 1 THEN
    RAISE EXCEPTION 'Order must contain at least one store';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM (
      SELECT DISTINCT (item ->> 'store_id')::uuid AS store_id
      FROM jsonb_array_elements(p_items) item
    ) requested_stores
    LEFT JOIN public.stores s ON s.id = requested_stores.store_id
    LEFT JOIN public.store_settings ss ON ss.store_id = s.id
    WHERE s.id IS NULL
       OR s.is_active = false
       OR COALESCE(ss.accepts_orders, true) = false
  ) THEN
    RAISE EXCEPTION 'One or more stores are inactive or not accepting delivery orders';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_store_id := (v_item ->> 'store_id')::uuid;
    v_qty := (v_item ->> 'quantity')::numeric;

    IF v_qty IS NULL OR v_qty <= 0 THEN
      RAISE EXCEPTION 'Invalid item quantity';
    END IF;

    SELECT *
    INTO v_product
    FROM public.products
    WHERE id = (v_item ->> 'product_id')::uuid
      AND store_id = v_store_id
      AND is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product not found, inactive, or belongs to another store';
    END IF;

    IF v_product.selling_method = 'value' THEN
      v_subtotal := v_subtotal + v_qty;
    ELSE
      v_subtotal := v_subtotal + (v_product.price * v_qty);
    END IF;
  END LOOP;

  IF v_store_count > 3 THEN
    v_delivery_fee := 25 + ((v_store_count - 3) * 5);
  END IF;

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
  RETURNING id INTO v_order_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_store_id := (v_item ->> 'store_id')::uuid;
    v_qty := (v_item ->> 'quantity')::numeric;

    SELECT *
    INTO v_product
    FROM public.products
    WHERE id = (v_item ->> 'product_id')::uuid
      AND store_id = v_store_id
      AND is_active = true;

    INSERT INTO public.order_items (
      order_id,
      store_id,
      product_id,
      product_name,
      unit_price,
      quantity,
      selling_method
    )
    VALUES (
      v_order_id,
      v_store_id,
      v_product.id,
      v_product.name,
      v_product.price,
      v_qty,
      v_product.selling_method
    );
  END LOOP;

  RETURN v_order_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_unified_order(uuid, jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_unified_order(uuid, jsonb, text) TO authenticated;

-- 8) Store Owner changes only the Store Portion state.
CREATE OR REPLACE FUNCTION public.store_owner_update_order_part_status(
  p_part_id uuid,
  p_status public.store_order_part_status
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  IF public.current_user_role() NOT IN ('store_owner', 'admin') THEN
    RAISE EXCEPTION 'Store owner privileges required';
  END IF;

  UPDATE public.order_store_parts osp
  SET status = p_status,
      updated_at = now()
  WHERE osp.id = p_part_id
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = osp.store_id
          AND s.owner_id = auth.uid()
      )
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order portion not found or access denied';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.store_owner_update_order_part_status(uuid, public.store_order_part_status) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.store_owner_update_order_part_status(uuid, public.store_order_part_status) TO authenticated;

-- 9) Prevent direct Store Owner changes to Store Portion identity/financial data.
CREATE OR REPLACE FUNCTION private.protect_order_store_part_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = private, public
AS $$
BEGIN
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.order_id IS DISTINCT FROM OLD.order_id
     OR NEW.store_id IS DISTINCT FROM OLD.store_id
     OR NEW.subtotal IS DISTINCT FROM OLD.subtotal
     OR NEW.item_count IS DISTINCT FROM OLD.item_count
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Store portion protected fields cannot be changed';
  END IF;

  NEW.ready_at := OLD.ready_at;
  NEW.picked_up_at := OLD.picked_up_at;
  NEW.updated_at := now();

  IF NEW.status = 'ready' AND OLD.status IS DISTINCT FROM 'ready' THEN
    NEW.ready_at := COALESCE(OLD.ready_at, now());
  END IF;

  IF NEW.status = 'picked_up' AND OLD.status IS DISTINCT FROM 'picked_up' THEN
    NEW.picked_up_at := COALESCE(OLD.picked_up_at, now());
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS order_store_parts_protect_mutation ON public.order_store_parts;
CREATE TRIGGER order_store_parts_protect_mutation
BEFORE UPDATE ON public.order_store_parts
FOR EACH ROW
EXECUTE FUNCTION private.protect_order_store_part_mutation();

COMMIT;
