-- Hena catalog seed
-- The previous catalog seed targeted the legacy catalog schema.
-- The current schema requires a real store_owner, so skip seeding
-- when no store owner exists yet.

DO $$
DECLARE
  v_owner_id uuid;
  v_store_id uuid;
BEGIN

  SELECT id
  INTO v_owner_id
  FROM public.profiles
  WHERE role = 'store_owner'::public.user_role
  ORDER BY created_at
  LIMIT 1;

  IF v_owner_id IS NULL THEN
    RAISE NOTICE 'No store_owner exists yet. Catalog seed skipped.';
    RETURN;
  END IF;

  SELECT id
  INTO v_store_id
  FROM public.stores
  WHERE owner_id = v_owner_id
    AND name = '?????'
  LIMIT 1;

  IF v_store_id IS NULL THEN

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
    RETURNING id INTO v_store_id;

  END IF;

END $$;
