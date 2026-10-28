-- =========================================================
-- HENA - DRIVER AVAILABILITY
-- =========================================================

CREATE TABLE IF NOT EXISTS public.driver_availability (
  driver_id uuid PRIMARY KEY
    REFERENCES public.profiles(id) ON DELETE CASCADE,

  is_available boolean NOT NULL DEFAULT true,

  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_driver_availability_available
  ON public.driver_availability(is_available);

ALTER TABLE public.driver_availability ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS driver_availability_select_own
ON public.driver_availability;

DROP POLICY IF EXISTS driver_availability_update_own
ON public.driver_availability;

DROP POLICY IF EXISTS driver_availability_insert_own
ON public.driver_availability;

DROP POLICY IF EXISTS driver_availability_delete_own
ON public.driver_availability;

CREATE POLICY driver_availability_select_own
ON public.driver_availability
FOR SELECT
TO authenticated
USING (
  driver_id = auth.uid()
);

CREATE POLICY driver_availability_insert_own
ON public.driver_availability
FOR INSERT
TO authenticated
WITH CHECK (
  driver_id = auth.uid()
);

CREATE POLICY driver_availability_update_own
ON public.driver_availability
FOR UPDATE
TO authenticated
USING (
  driver_id = auth.uid()
)
WITH CHECK (
  driver_id = auth.uid()
);

CREATE POLICY driver_availability_delete_own
ON public.driver_availability
FOR DELETE
TO authenticated
USING (
  driver_id = auth.uid()
);

GRANT SELECT, INSERT, UPDATE, DELETE
ON public.driver_availability
TO authenticated;

CREATE OR REPLACE FUNCTION public.set_my_driver_availability(
  p_is_available boolean
)
RETURNS public.driver_availability
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
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
  RETURNING *
  INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE ALL
ON FUNCTION public.set_my_driver_availability(boolean)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.set_my_driver_availability(boolean)
TO authenticated;
