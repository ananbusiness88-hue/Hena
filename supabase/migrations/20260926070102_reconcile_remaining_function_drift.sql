SET check_function_bodies = false;

ALTER FUNCTION public.record_order_status_change()
SECURITY DEFINER;

ALTER FUNCTION public.record_order_status_change()
RESET search_path;

ALTER FUNCTION public.record_order_status_change()
SET search_path TO public, pg_temp;

CREATE OR REPLACE FUNCTION public.set_my_driver_availability(
    p_is_available boolean
)
RETURNS public.driver_availability
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
    v_result public.driver_availability;
BEGIN
    INSERT INTO public.driver_availability (
        driver_id,
        is_available,
        updated_at
    )
    VALUES (
        auth.uid(),
        p_is_available,
        now()
    )
    ON CONFLICT (driver_id)
    DO UPDATE SET
        is_available = EXCLUDED.is_available,
        updated_at = now()
    RETURNING * INTO v_result;

    RETURN v_result;
END;
$function$;
