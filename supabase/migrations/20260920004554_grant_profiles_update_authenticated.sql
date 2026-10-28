-- Allow authenticated users to update their own profile.
-- Row-level ownership remains enforced by profiles RLS.

GRANT UPDATE
ON TABLE public.profiles
TO authenticated;
