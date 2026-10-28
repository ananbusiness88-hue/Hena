BEGIN;

CREATE OR REPLACE FUNCTION public.driver_accept_order(
  p_order_id uuid
)
RETURNS public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
  v_driver_id uuid := auth.uid();
  v_is_suspended boolean := false;
BEGIN
  /*
    The caller must be an active Driver.
  */
  IF public.current_user_role() <> 'driver'::public.user_role THEN
    RAISE EXCEPTION 'Only active drivers can accept orders';
  END IF;

  /*
    A missing daily-limit row means the driver has no suspension record.
  */
  SELECT COALESCE(
      (
        SELECT ddl.is_suspended
        FROM public.driver_daily_limits ddl
        WHERE ddl.driver_id = v_driver_id
          AND ddl.limit_date = CURRENT_DATE
        LIMIT 1
      ),
      false
    )
  INTO v_is_suspended;

  IF v_is_suspended THEN
    RAISE EXCEPTION 'Driver is suspended';
  END IF;

  /*
    Atomic claim:
    only a ready Unified Order with no driver can be accepted.
  */
  UPDATE public.orders
  SET driver_id = v_driver_id,
      status = 'assigned'::public.order_status
  WHERE id = p_order_id
    AND status = 'ready'::public.order_status
    AND driver_id IS NULL
  RETURNING *
  INTO v_order;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order is no longer available for acceptance';
  END IF;

  RETURN v_order;
END;
$function$;


REVOKE ALL ON FUNCTION public.driver_accept_order(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.driver_accept_order(uuid)
TO authenticated;

COMMIT;
