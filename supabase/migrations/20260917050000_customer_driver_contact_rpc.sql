CREATE OR REPLACE FUNCTION public.customer_get_assigned_driver_contact(
  p_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid;
  v_driver_name text;
  v_driver_phone text;
BEGIN
  SELECT driver_id
  INTO v_driver_id
  FROM public.orders
  WHERE id = p_order_id
    AND customer_id = auth.uid();

  IF v_driver_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT full_name, phone
  INTO v_driver_name, v_driver_phone
  FROM public.profiles
  WHERE id = v_driver_id
    AND role = 'driver'::public.user_role
    AND is_active = true;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'full_name', v_driver_name,
    'phone', v_driver_phone
  );
END;
$$;

REVOKE ALL ON FUNCTION public.customer_get_assigned_driver_contact(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.customer_get_assigned_driver_contact(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.customer_get_assigned_driver_contact(uuid) TO authenticated;
