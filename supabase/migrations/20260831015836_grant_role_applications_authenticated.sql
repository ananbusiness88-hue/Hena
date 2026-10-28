-- Hena: restore role_applications on the remote environment.
-- The initial migration is already marked as applied remotely,
-- but the role_applications table is missing.
--
-- This creates the current/final table shape directly.
-- Migration 20260831025605 remains safe because its DROP IF EXISTS
-- operations become no-ops before it re-adds the applicant FK.

DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'role_application_status'
  ) THEN
    CREATE TYPE public.role_application_status AS ENUM (
      'pending',
      'approved',
      'rejected',
      'cancelled'
    );
  END IF;
END
$do$;

CREATE TABLE IF NOT EXISTS public.role_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  applicant_id uuid NOT NULL,
  requested_role public.user_role NOT NULL,
  status public.role_application_status NOT NULL DEFAULT 'pending',
  notes text,
  reviewed_by_admin_id uuid,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT role_applicant_fk
    FOREIGN KEY (applicant_id)
    REFERENCES public.profiles(id)
    ON DELETE RESTRICT,

  CONSTRAINT role_reviewer_fk
    FOREIGN KEY (reviewed_by_admin_id)
    REFERENCES public.profiles(id)
    ON DELETE RESTRICT,

  CONSTRAINT role_application_requested_role
    CHECK (requested_role IN ('driver', 'store_owner')),

  CONSTRAINT role_application_review_consistency
    CHECK (
      (status = 'pending'
       AND reviewed_by_admin_id IS NULL
       AND reviewed_at IS NULL)
      OR
      (status IN ('approved', 'rejected', 'cancelled')
       AND reviewed_by_admin_id IS NOT NULL
       AND reviewed_at IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_role_applications_applicant
  ON public.role_applications(applicant_id);

CREATE INDEX IF NOT EXISTS idx_role_applications_status
  ON public.role_applications(status);

CREATE UNIQUE INDEX IF NOT EXISTS uq_pending_role_application
  ON public.role_applications(applicant_id, requested_role)
  WHERE status = 'pending';

ALTER TABLE public.role_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS role_applications_select_own
ON public.role_applications;

DROP POLICY IF EXISTS role_applications_insert_own
ON public.role_applications;

DROP POLICY IF EXISTS role_applications_admin
ON public.role_applications;

CREATE POLICY role_applications_select_own
ON public.role_applications
FOR SELECT
TO authenticated
USING (applicant_id = auth.uid());

CREATE POLICY role_applications_insert_own
ON public.role_applications
FOR INSERT
TO authenticated
WITH CHECK (
  applicant_id = auth.uid()
  AND requested_role IN ('driver', 'store_owner')
  AND status = 'pending'
);

CREATE POLICY role_applications_admin
ON public.role_applications
FOR SELECT
TO authenticated
USING (public.is_admin());

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trigger_role_applications_updated_at
ON public.role_applications;

CREATE TRIGGER trigger_role_applications_updated_at
BEFORE UPDATE ON public.role_applications
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

REVOKE ALL ON TABLE public.role_applications FROM anon, authenticated;

GRANT SELECT, INSERT
ON TABLE public.role_applications
TO authenticated;
