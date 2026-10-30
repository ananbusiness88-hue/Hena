-- ============================================================
-- HENA - Expose the default delivery area fee
--
-- public.delivery_settings gained the column default_area_fee
-- (the fallback fee that is charged for an address that does not
-- match any area of the delivery areas catalog), but the
-- get_delivery_settings() function did not return it, so the
-- admin console could not read nor display the current value.
--
-- The function is replaced with the exact same body, the only
-- difference is the extra "default_area_fee" key in the returned
-- jsonb object. Every other key (base_fee, included_stores,
-- extra_store_fee, updated_at) and every other behaviour (the
-- exception when the settings are not configured, the security
-- definer and the grants) is preserved.
--
-- The value is written with the existing
-- admin_update_default_area_fee() function, this migration only
-- exposes the current value for reading.
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
    'default_area_fee', v_settings.default_area_fee,
    'updated_at', v_settings.updated_at
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_delivery_settings() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_delivery_settings() TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_delivery_settings() TO anon;
