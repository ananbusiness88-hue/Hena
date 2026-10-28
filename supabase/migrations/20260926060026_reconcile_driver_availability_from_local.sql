-- Reconcile Remote driver_availability with the verified Local source of truth.

ALTER TABLE public.driver_availability
ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS driver_availability_delete_own
ON public.driver_availability;

DROP POLICY IF EXISTS driver_availability_insert_own
ON public.driver_availability;

DROP POLICY IF EXISTS driver_availability_select_own
ON public.driver_availability;

DROP POLICY IF EXISTS driver_availability_update_own
ON public.driver_availability;

CREATE POLICY driver_availability_delete_own
ON public.driver_availability
FOR DELETE
TO authenticated
USING (driver_id = auth.uid());

CREATE POLICY driver_availability_insert_own
ON public.driver_availability
FOR INSERT
TO authenticated
WITH CHECK (driver_id = auth.uid());

CREATE POLICY driver_availability_select_own
ON public.driver_availability
FOR SELECT
TO authenticated
USING (driver_id = auth.uid());

CREATE POLICY driver_availability_update_own
ON public.driver_availability
FOR UPDATE
TO authenticated
USING (driver_id = auth.uid())
WITH CHECK (driver_id = auth.uid());

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
$;
