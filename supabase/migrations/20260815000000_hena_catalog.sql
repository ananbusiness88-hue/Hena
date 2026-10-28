-- Hena Catalog
-- Compatible with the existing Hena initial_schema.
-- stores and products already exist in initial_schema.

-- =========================================================
-- PRODUCT PRICING TYPE
-- =========================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'product_pricing_type'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    CREATE TYPE public.product_pricing_type AS ENUM (
      'unit',
      'weight',
      'value',
      'fraction'
    );
  END IF;
END
$$;


-- =========================================================
-- STORE CATEGORIES
-- =========================================================

CREATE TABLE public.store_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  name text NOT NULL,
  description text,
  image_url text,

  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT store_categories_name_unique UNIQUE (name)
);

CREATE INDEX store_categories_active_sort_idx
ON public.store_categories(is_active, sort_order);


-- =========================================================
-- STORE SETTINGS
-- =========================================================

CREATE TABLE public.store_settings (
  store_id uuid PRIMARY KEY
    REFERENCES public.stores(id)
    ON DELETE CASCADE,

  accepts_orders boolean NOT NULL DEFAULT true,

  minimum_order_amount numeric(12,2) NOT NULL DEFAULT 0,

  preparation_time_minutes integer,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT store_settings_minimum_order_nonnegative
    CHECK (minimum_order_amount >= 0),

  CONSTRAINT store_settings_preparation_time_positive
    CHECK (
      preparation_time_minutes IS NULL
      OR preparation_time_minutes > 0
    )
);


-- =========================================================
-- PRODUCT CATEGORIES
-- =========================================================

CREATE TABLE public.product_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  store_id uuid NOT NULL
    REFERENCES public.stores(id)
    ON DELETE CASCADE,

  name text NOT NULL,
  description text,
  image_url text,

  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT product_categories_store_name_unique
    UNIQUE (store_id, name)
);

CREATE INDEX product_categories_store_id_idx
ON public.product_categories(store_id);

CREATE INDEX product_categories_active_sort_idx
ON public.product_categories(
  store_id,
  is_active,
  sort_order
);


-- =========================================================
-- LINK EXISTING PRODUCTS TO PRODUCT CATEGORIES
-- =========================================================

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS category_id uuid;

ALTER TABLE public.products
ADD CONSTRAINT products_category_fk
FOREIGN KEY (category_id)
REFERENCES public.product_categories(id)
ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS products_category_id_idx
ON public.products(category_id);


-- =========================================================
-- PRODUCT / CATEGORY CONSISTENCY
-- =========================================================

CREATE OR REPLACE FUNCTION public.validate_product_category_store()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN

  IF NEW.category_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM public.product_categories pc
       WHERE pc.id = NEW.category_id
         AND pc.store_id = NEW.store_id
     )
  THEN
    RAISE EXCEPTION
      'Product category does not belong to the same store';
  END IF;

  RETURN NEW;

END;
$$;

DROP TRIGGER IF EXISTS products_validate_category_store
ON public.products;

CREATE TRIGGER products_validate_category_store
BEFORE INSERT OR UPDATE OF store_id, category_id
ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.validate_product_category_store();


-- =========================================================
-- PRODUCT PRICING
-- =========================================================

CREATE TABLE public.product_pricing (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  product_id uuid NOT NULL
    REFERENCES public.products(id)
    ON DELETE CASCADE,

  pricing_type public.product_pricing_type NOT NULL,

  unit_name text,

  quantity numeric(12,3),

  price numeric(12,2) NOT NULL,

  fraction_value numeric(12,6),

  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT product_pricing_price_nonnegative
    CHECK (price >= 0),

  CONSTRAINT product_pricing_quantity_positive
    CHECK (
      quantity IS NULL
      OR quantity > 0
    ),

  CONSTRAINT product_pricing_fraction_valid
    CHECK (
      fraction_value IS NULL
      OR (
        fraction_value > 0
        AND fraction_value <= 1
      )
    ),

  CONSTRAINT product_pricing_unit_name_not_blank
    CHECK (
      unit_name IS NULL
      OR length(trim(unit_name)) > 0
    )
);

CREATE INDEX product_pricing_product_id_idx
ON public.product_pricing(product_id);

CREATE INDEX product_pricing_active_sort_idx
ON public.product_pricing(
  product_id,
  is_active,
  sort_order
);


-- =========================================================
-- UPDATED_AT TRIGGERS
-- =========================================================

CREATE TRIGGER store_categories_updated_at
BEFORE UPDATE ON public.store_categories
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER store_settings_updated_at
BEFORE UPDATE ON public.store_settings
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER product_categories_updated_at
BEFORE UPDATE ON public.product_categories
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER product_pricing_updated_at
BEFORE UPDATE ON public.product_pricing
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at();


-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

ALTER TABLE public.store_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_pricing ENABLE ROW LEVEL SECURITY;


-- =========================================================
-- PUBLIC CATALOG READ
-- =========================================================

CREATE POLICY "Active store categories are viewable"
ON public.store_categories
FOR SELECT
USING (
  is_active = true
);


CREATE POLICY "Active store settings are viewable"
ON public.store_settings
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.stores s
    WHERE s.id = store_settings.store_id
      AND s.is_active = true
  )
);


CREATE POLICY "Active product categories are viewable"
ON public.product_categories
FOR SELECT
USING (
  is_active = true
  AND EXISTS (
    SELECT 1
    FROM public.stores s
    WHERE s.id = product_categories.store_id
      AND s.is_active = true
  )
);


CREATE POLICY "Active product pricing is viewable"
ON public.product_pricing
FOR SELECT
USING (
  is_active = true
  AND EXISTS (
    SELECT 1
    FROM public.products p
    JOIN public.stores s
      ON s.id = p.store_id
    WHERE p.id = product_pricing.product_id
      AND p.is_active = true
      AND s.is_active = true
  )
);


-- =========================================================
-- ADMIN WRITE POLICIES
-- These are intentionally simple.
-- 20260817000254_fix_admin_policy_roles.sql
-- will harden them for authenticated admins.
-- =========================================================

CREATE POLICY "Admins manage store categories"
ON public.store_categories
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);


CREATE POLICY "Admins manage store settings"
ON public.store_settings
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);


CREATE POLICY "Admins manage product categories"
ON public.product_categories
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);


CREATE POLICY "Admins manage product pricing"
ON public.product_pricing
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);
