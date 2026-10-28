-- Hena: role applications must reference the applicant identity,
-- not the applicant's current role.
--
-- The applicant can legitimately change role after admin approval,
-- so a composite FK on (applicant_id, applicant_role) would block
-- the promotion from customer -> store_owner/driver.

ALTER TABLE public.role_applications
  DROP CONSTRAINT IF EXISTS role_applicant_fk;

ALTER TABLE public.role_applications
  DROP COLUMN IF EXISTS applicant_role;

ALTER TABLE public.role_applications
  ADD CONSTRAINT role_applicant_fk
  FOREIGN KEY (applicant_id)
  REFERENCES public.profiles(id)
  ON DELETE RESTRICT;
