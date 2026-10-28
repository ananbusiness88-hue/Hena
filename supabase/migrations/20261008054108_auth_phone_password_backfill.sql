-- Hena: backfill auth.users.phone from public.profiles.phone
-- Existing users only. No new accounts are created.

BEGIN;

-- Guard 1:
-- The profile phone must be unique before it is used as an Auth identifier.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE NULLIF(trim(phone), '') IS NOT NULL
    GROUP BY trim(phone)
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION
      'AUTH PHONE BACKFILL ABORTED: duplicate phone numbers exist in public.profiles.';
  END IF;
END;
$$;

-- Guard 2:
-- A profile phone must not already belong to a different auth.users row.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.profiles p
    JOIN auth.users u
      ON NULLIF(trim(u.phone), '') = NULLIF(trim(p.phone), '')
     AND u.id <> p.id
    WHERE NULLIF(trim(p.phone), '') IS NOT NULL
  ) THEN
    RAISE EXCEPTION
      'AUTH PHONE BACKFILL ABORTED: a profile phone already belongs to another auth user.';
  END IF;
END;
$$;

-- Backfill only users whose Auth phone is currently empty.
UPDATE auth.users AS u
SET
  phone = trim(p.phone),
  updated_at = now()
FROM public.profiles AS p
WHERE p.id = u.id
  AND NULLIF(trim(u.phone), '') IS NULL
  AND NULLIF(trim(p.phone), '') IS NOT NULL;

COMMIT;