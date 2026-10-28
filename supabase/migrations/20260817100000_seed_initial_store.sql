-- Hena Initial Store Seed
-- Store creation requires a real store_owner profile.
-- Do not create a fake owner during database reset.

DO $$
DECLARE
  v_owner_id uuid;
BEGIN

  SELECT id
  INTO v_owner_id
  FROM public.profiles
  WHERE role = 'store_owner'::public.user_role
  ORDER BY created_at
  LIMIT 1;

  IF v_owner_id IS NULL THEN
    RAISE NOTICE 'No store_owner profile exists. Initial store seed skipped.';
    RETURN;
  END IF;

  INSERT INTO public.stores (
    owner_id,
    name,
    description,
    category,
    phone,
    address,
    is_active
  )
  VALUES (
    v_owner_id,
    '?????',
    '???? ????? ?????',
    'supermarkets'::public.store_category,
    '',
    '',
    true
  )
  ON CONFLICT DO NOTHING;

END $$;
