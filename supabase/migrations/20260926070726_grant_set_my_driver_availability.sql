-- Sync verified Local privileges to Remote.

GRANT ALL ON FUNCTION public.set_my_driver_availability(boolean) TO PUBLIC;
GRANT ALL ON FUNCTION public.set_my_driver_availability(boolean) TO anon;
GRANT ALL ON FUNCTION public.set_my_driver_availability(boolean) TO service_role;
