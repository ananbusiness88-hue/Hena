-- ============================================================
-- HENA: STORE ORDER PARTS
-- One unified order can contain multiple stores.
-- Each store gets an independent operational portion.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Store portion status
-- preparing  = قيد التجهيز
-- ready      = في انتظار المندوب / جاهز للتسليم
-- picked_up  = تم التسليم للمندوب
-- ------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typnamespace = 'public'::regnamespace
      AND typname = 'store_order_part_status'
  ) THEN
    CREATE TYPE public.store_order_part_status AS ENUM (
      'preparing',
      'ready',
      'picked_up'
    );
  END IF;
END
$$;

-- ------------------------------------------------------------
-- 2. Store order parts
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.order_store_parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  order_id uuid NOT NULL
    REFERENCES public.orders(id)
    ON DELETE CASCADE,

  store_id uuid NOT NULL
    REFERENCES public.stores(id)
    ON DELETE RESTRICT,

  status public.store_order_part_status NOT NULL DEFAULT 'preparing',

  subtotal numeric(12,2) NOT NULL DEFAULT 0
    CHECK (subtotal >= 0),

  item_count integer NOT NULL DEFAULT 0
    CHECK (item_count >= 0),

  ready_at timestamptz,
  picked_up_at timestamptz,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT order_store_parts_order_store_unique
    UNIQUE (order_id, store_id)
);

CREATE INDEX IF NOT EXISTS idx_order_store_parts_order_id
  ON public.order_store_parts(order_id);

CREATE INDEX IF NOT EXISTS idx_order_store_parts_store_id
  ON public.order_store_parts(store_id);

CREATE INDEX IF NOT EXISTS idx_order_store_parts_store_status
  ON public.order_store_parts(store_id, status);

-- ------------------------------------------------------------
-- 3. Keep updated_at current
-- ------------------------------------------------------------

DROP TRIGGER IF EXISTS order_store_parts_set_updated_at
ON public.order_store_parts;

CREATE TRIGGER order_store_parts_set_updated_at
BEFORE UPDATE ON public.order_store_parts
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at();

-- ------------------------------------------------------------
-- 4. Synchronize store portions from order_items
--
-- Whenever an item is inserted/updated/deleted, the matching
-- store portion is created or recalculated automatically.
-- ------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.sync_order_store_part()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN

  -- Current / new store portion
  IF TG_OP IN ('INSERT', 'UPDATE') THEN

    INSERT INTO public.order_store_parts (
      order_id,
      store_id,
      subtotal,
      item_count
    )
    SELECT
      NEW.order_id,
      NEW.store_id,
      COALESCE(SUM(oi.item_total), 0),
      COUNT(*)::integer
    FROM public.order_items oi
    WHERE oi.order_id = NEW.order_id
      AND oi.store_id = NEW.store_id
    ON CONFLICT (order_id, store_id)
    DO UPDATE SET
      subtotal = EXCLUDED.subtotal,
      item_count = EXCLUDED.item_count,
      updated_at = now();

  END IF;

  -- If an existing item moved/deleted, recalculate the old
  -- store portion as well.
  IF TG_OP = 'DELETE'
     OR (
       TG_OP = 'UPDATE'
       AND (
         OLD.order_id IS DISTINCT FROM NEW.order_id
         OR OLD.store_id IS DISTINCT FROM NEW.store_id
       )
     )
  THEN

    IF EXISTS (
      SELECT 1
      FROM public.order_items oi
      WHERE oi.order_id = OLD.order_id
        AND oi.store_id = OLD.store_id
    ) THEN

      UPDATE public.order_store_parts osp
      SET
        subtotal = COALESCE((
          SELECT SUM(oi.item_total)
          FROM public.order_items oi
          WHERE oi.order_id = OLD.order_id
            AND oi.store_id = OLD.store_id
        ), 0),
        item_count = (
          SELECT COUNT(*)::integer
          FROM public.order_items oi
          WHERE oi.order_id = OLD.order_id
            AND oi.store_id = OLD.store_id
        ),
        updated_at = now()
      WHERE osp.order_id = OLD.order_id
        AND osp.store_id = OLD.store_id;

    ELSE

      DELETE FROM public.order_store_parts
      WHERE order_id = OLD.order_id
        AND store_id = OLD.store_id;

    END IF;

  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.sync_order_store_part()
FROM PUBLIC;

DROP TRIGGER IF EXISTS order_items_sync_store_part
ON public.order_items;

CREATE TRIGGER order_items_sync_store_part
AFTER INSERT OR UPDATE OR DELETE
ON public.order_items
FOR EACH ROW
EXECUTE FUNCTION private.sync_order_store_part();

-- ------------------------------------------------------------
-- 5. Enforce valid operational status transitions
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.validate_order_store_part_status()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

  IF NEW.status = OLD.status THEN
    NEW.updated_at = now();
    RETURN NEW;
  END IF;

  -- Super Admin may make administrative corrections.
  IF is_admin() THEN

    IF NEW.status = 'ready'
       AND NEW.ready_at IS NULL THEN
      NEW.ready_at = now();
    END IF;

    IF NEW.status = 'picked_up'
       AND NEW.picked_up_at IS NULL THEN
      NEW.picked_up_at = now();
    END IF;

    NEW.updated_at = now();
    RETURN NEW;
  END IF;

  -- Normal Store Owner / Driver workflow.
  IF OLD.status = 'preparing'
     AND NEW.status = 'ready' THEN

    NEW.ready_at = COALESCE(NEW.ready_at, now());
    NEW.updated_at = now();
    RETURN NEW;

  ELSIF OLD.status = 'ready'
        AND NEW.status = 'picked_up' THEN

    NEW.picked_up_at = COALESCE(NEW.picked_up_at, now());
    NEW.updated_at = now();
    RETURN NEW;

  END IF;

  RAISE EXCEPTION
    'Invalid store order part status transition: % -> %',
    OLD.status,
    NEW.status;
END;
$$;

DROP TRIGGER IF EXISTS validate_order_store_part_status
ON public.order_store_parts;

CREATE TRIGGER validate_order_store_part_status
BEFORE UPDATE OF status
ON public.order_store_parts
FOR EACH ROW
EXECUTE FUNCTION public.validate_order_store_part_status();

-- ------------------------------------------------------------
-- 6. RLS
-- ------------------------------------------------------------

ALTER TABLE public.order_store_parts
ENABLE ROW LEVEL SECURITY;

REVOKE ALL
ON TABLE public.order_store_parts
FROM anon, authenticated;

GRANT SELECT, UPDATE
ON TABLE public.order_store_parts
TO authenticated;

DROP POLICY IF EXISTS order_store_parts_select_admin
ON public.order_store_parts;

CREATE POLICY order_store_parts_select_admin
ON public.order_store_parts
FOR SELECT
TO authenticated
USING (
  is_admin()
);

DROP POLICY IF EXISTS order_store_parts_select_customer
ON public.order_store_parts;

CREATE POLICY order_store_parts_select_customer
ON public.order_store_parts
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.orders o
    WHERE o.id = order_store_parts.order_id
      AND o.customer_id = auth.uid()
  )
);

DROP POLICY IF EXISTS order_store_parts_select_store_owner
ON public.order_store_parts;

CREATE POLICY order_store_parts_select_store_owner
ON public.order_store_parts
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.stores s
    WHERE s.id = order_store_parts.store_id
      AND s.owner_id = auth.uid()
  )
);

DROP POLICY IF EXISTS order_store_parts_select_driver
ON public.order_store_parts;

CREATE POLICY order_store_parts_select_driver
ON public.order_store_parts
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.orders o
    WHERE o.id = order_store_parts.order_id
      AND o.driver_id = auth.uid()
  )
);

-- ------------------------------------------------------------
-- 7. Store Owner update:
-- only his own store portions
-- ------------------------------------------------------------

DROP POLICY IF EXISTS order_store_parts_update_store_owner
ON public.order_store_parts;

CREATE POLICY order_store_parts_update_store_owner
ON public.order_store_parts
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.stores s
    WHERE s.id = order_store_parts.store_id
      AND s.owner_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.stores s
    WHERE s.id = order_store_parts.store_id
      AND s.owner_id = auth.uid()
  )
);

-- ------------------------------------------------------------
-- 8. Driver may confirm pickup on assigned orders
-- ------------------------------------------------------------

DROP POLICY IF EXISTS order_store_parts_update_driver
ON public.order_store_parts;

CREATE POLICY order_store_parts_update_driver
ON public.order_store_parts
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.orders o
    WHERE o.id = order_store_parts.order_id
      AND o.driver_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.orders o
    WHERE o.id = order_store_parts.order_id
      AND o.driver_id = auth.uid()
  )
);

-- ------------------------------------------------------------
-- 9. Admin full access
-- ------------------------------------------------------------

DROP POLICY IF EXISTS order_store_parts_update_admin
ON public.order_store_parts;

CREATE POLICY order_store_parts_update_admin
ON public.order_store_parts
FOR UPDATE
TO authenticated
USING (
  is_admin()
)
WITH CHECK (
  is_admin()
);

-- ------------------------------------------------------------
-- 10. Backfill portions for any existing orders
-- ------------------------------------------------------------

INSERT INTO public.order_store_parts (
  order_id,
  store_id,
  subtotal,
  item_count
)
SELECT
  oi.order_id,
  oi.store_id,
  COALESCE(SUM(oi.item_total), 0),
  COUNT(*)::integer
FROM public.order_items oi
GROUP BY oi.order_id, oi.store_id
ON CONFLICT (order_id, store_id)
DO UPDATE SET
  subtotal = EXCLUDED.subtotal,
  item_count = EXCLUDED.item_count,
  updated_at = now();

-- ------------------------------------------------------------
-- 11. Store Owner sees an order if any portion belongs
--     to his store.
-- ------------------------------------------------------------

DROP POLICY IF EXISTS orders_select_store_owner
ON public.orders;

CREATE POLICY orders_select_store_owner
ON public.orders
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.order_store_parts osp
    JOIN public.stores s
      ON s.id = osp.store_id
    WHERE osp.order_id = orders.id
      AND s.owner_id = auth.uid()
  )
);

-- Store Owner must NOT update the unified order itself.
DROP POLICY IF EXISTS orders_update_store_owner
ON public.orders;

-- ------------------------------------------------------------
-- 12. Store Owner sees items by the actual item store.
-- ------------------------------------------------------------

DROP POLICY IF EXISTS order_items_select_store_owner
ON public.order_items;

CREATE POLICY order_items_select_store_owner
ON public.order_items
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.stores s
    WHERE s.id = order_items.store_id
      AND s.owner_id = auth.uid()
  )
);

-- ------------------------------------------------------------
-- 13. Security indexes for ownership checks
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_stores_owner_id
  ON public.stores(owner_id);

COMMENT ON TABLE public.order_store_parts IS
  'Operational portion of a unified order belonging to one store. Store Owner controls only this portion.';
