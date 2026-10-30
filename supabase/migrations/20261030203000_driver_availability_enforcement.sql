-- ============================================================
-- HENA - Driver availability enforcement
--
-- A driver who switches to "غير متاح للتوصيل" must be blocked
-- on the BACKEND, not only in the Flutter UI:
--   * must not see unassigned ("ready") orders
--   * must not be able to claim an order through any RPC
--   * must not receive realtime rows for new orders
--
-- The driver_availability table and set_my_driver_availability()
-- already exist and already persist the state; this migration adds
-- the missing enforcement layer.
--
-- Orders already assigned to the driver stay visible so an active
-- delivery can always be finished.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Single source of truth for availability.
--
-- A missing row means "available" which matches the existing
-- Flutter behaviour (getMyAvailability falls back to true).
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_driver_available(
  p_driver_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT COALESCE(
    (
      SELECT da.is_available
      FROM public.driver_availability da
      WHERE da.driver_id = p_driver_id
      LIMIT 1
    ),
    true
  );
$function$;

REVOKE ALL ON FUNCTION public.is_driver_available(uuid)
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.is_driver_available(uuid)
TO authenticated;

GRANT EXECUTE ON FUNCTION public.is_driver_available(uuid)
TO anon;

-- ------------------------------------------------------------
-- 2. Block order discovery for unavailable drivers.
--
-- The "ready and unassigned" branch is the order-discovery branch:
-- it is what getAvailableOrders() reads and what realtime
-- broadcasts. The "already mine" branch is deliberately left
-- untouched so an in-flight delivery can still be completed.
-- ------------------------------------------------------------

DROP POLICY IF EXISTS "orders_select_driver" ON "public"."orders";

CREATE POLICY "orders_select_driver" ON "public"."orders"
FOR SELECT TO "authenticated"
USING (
  ("driver_id" = "auth"."uid"())
  OR (
    ("status" = 'ready'::"public"."order_status")
    AND ("driver_id" IS NULL)
    AND "public"."is_driver_available"("auth"."uid"())
  )
);

DROP POLICY IF EXISTS "order_items_select_driver"
ON "public"."order_items";

CREATE POLICY "order_items_select_driver" ON "public"."order_items"
FOR SELECT TO "authenticated"
USING (
  EXISTS (
    SELECT 1
    FROM "public"."orders" "o"
    WHERE ("o"."id" = "order_items"."order_id")
      AND (
        ("o"."driver_id" = "auth"."uid"())
        OR (
          ("o"."status" = 'ready'::"public"."order_status")
          AND ("o"."driver_id" IS NULL)
          AND "public"."is_driver_available"("auth"."uid"())
        )
      )
  )
);

DROP POLICY IF EXISTS "order_store_parts_select_driver"
ON "public"."order_store_parts";

CREATE POLICY "order_store_parts_select_driver"
ON "public"."order_store_parts"
FOR SELECT TO "authenticated"
USING (
  EXISTS (
    SELECT 1
    FROM "public"."orders" "o"
    WHERE ("o"."id" = "order_store_parts"."order_id")
      AND (
        ("o"."driver_id" = "auth"."uid"())
        OR (
          ("o"."status" = 'ready'::"public"."order_status")
          AND ("o"."driver_id" IS NULL)
          AND "public"."is_driver_available"("auth"."uid"())
        )
      )
  )
);

-- ------------------------------------------------------------
-- 3. Block claiming through the authoritative RPC.
--
-- The function body is patched in place so that every existing
-- guard (role check, suspension check, atomic claim) is kept.
-- If the expected anchor text is not found the migration fails
-- loudly and nothing is applied.
-- ------------------------------------------------------------

DO $block$
DECLARE
  v_definition text;
  v_anchor text;
  v_insert text;
BEGIN
  SELECT pg_get_functiondef(
    'public.driver_accept_order(uuid)'::regprocedure
  )
  INTO v_definition;

  IF v_definition IS NULL THEN
    RAISE EXCEPTION
      'driver_accept_order(uuid) was not found';
  END IF;

  IF position(
    'public.is_driver_available'
    IN v_definition
  ) <> 0 THEN
    RAISE EXCEPTION
      'driver_accept_order already contains availability logic';
  END IF;

  v_anchor :=
    E'  IF public.current_user_role() <> ''driver''::public.user_role THEN\n' ||
    E'    RAISE EXCEPTION ''Only active drivers can accept orders'';\n' ||
    E'  END IF;';

  v_insert :=
    v_anchor ||
    E'\n\n' ||
    E'  /*\n' ||
    E'    Availability gate: a driver who marked themselves as\n' ||
    E'    unavailable cannot claim an order.\n' ||
    E'  */\n' ||
    E'  IF NOT public.is_driver_available(v_driver_id) THEN\n' ||
    E'    RAISE EXCEPTION ''Driver is not available for delivery'';\n' ||
    E'  END IF;';

  IF position(v_anchor IN v_definition) = 0 THEN
    RAISE EXCEPTION
      'Expected role-guard block was not found in driver_accept_order';
  END IF;

  v_definition := replace(v_definition, v_anchor, v_insert);

  EXECUTE v_definition;
END;
$block$;

-- ------------------------------------------------------------
-- 4. Verification: the guard and the policies must be in place.
-- ------------------------------------------------------------

DO $verify$
DECLARE
  v_definition text;
  v_policy text;
BEGIN
  SELECT pg_get_functiondef(
    'public.driver_accept_order(uuid)'::regprocedure
  )
  INTO v_definition;

  IF position(
    'public.is_driver_available(v_driver_id)'
    IN v_definition
  ) = 0 THEN
    RAISE EXCEPTION
      'Availability guard is missing from driver_accept_order';
  END IF;

  SELECT pg_get_expr(pol.polqual, pol.polrelid)
  INTO v_policy
  FROM pg_policy pol
  WHERE pol.polrelid = 'public.orders'::regclass
    AND pol.polname = 'orders_select_driver';

  IF v_policy IS NULL THEN
    RAISE EXCEPTION 'orders_select_driver policy is missing';
  END IF;

  IF position('is_driver_available' IN v_policy) = 0 THEN
    RAISE EXCEPTION
      'orders_select_driver does not enforce driver availability';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'is_driver_available'
  ) THEN
    RAISE EXCEPTION 'is_driver_available function is missing';
  END IF;
END;
$verify$;
