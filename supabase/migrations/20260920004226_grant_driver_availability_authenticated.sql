-- Allow authenticated users to read and manage their own driver availability.
-- Row-level security remains responsible for ownership enforcement.

GRANT SELECT, INSERT, UPDATE
ON TABLE public.driver_availability
TO authenticated;
