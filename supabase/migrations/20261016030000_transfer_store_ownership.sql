CREATE TABLE public.store_ownership_transfers (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id uuid REFERENCES public.stores(id) ON DELETE SET NULL,
    store_name_at_transfer text NOT NULL,
    previous_owner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    previous_owner_name_at_transfer text,
    new_owner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    new_owner_name_at_transfer text NOT NULL,
    transferred_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    transferred_by_name text,
    transferred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX store_ownership_transfers_store_time_idx
    ON public.store_ownership_transfers (store_id, transferred_at DESC);

ALTER TABLE public.store_ownership_transfers ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.store_ownership_transfers FROM anon, authenticated;
GRANT SELECT ON TABLE public.store_ownership_transfers TO authenticated;

CREATE POLICY store_ownership_transfers_admin_select
    ON public.store_ownership_transfers
    FOR SELECT
    TO authenticated
    USING (public.is_admin());

CREATE OR REPLACE FUNCTION public.transfer_store_ownership(
    p_store_id uuid,
    p_new_owner_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_admin_id uuid;
    v_admin_name text;
    v_store_name text;
    v_previous_owner_id uuid;
    v_previous_owner_name text;
    v_new_owner_name text;
BEGIN
    v_admin_id := auth.uid();

    IF v_admin_id IS NULL OR NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only an authenticated active admin can transfer store ownership';
    END IF;

    IF p_store_id IS NULL OR p_new_owner_id IS NULL THEN
        RAISE EXCEPTION 'Store ID and new owner ID are required';
    END IF;

    SELECT s.owner_id, s.name
      INTO v_previous_owner_id, v_store_name
      FROM public.stores AS s
     WHERE s.id = p_store_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Store not found';
    END IF;

    IF v_previous_owner_id = p_new_owner_id THEN
        RAISE EXCEPTION 'The selected user is already the store owner';
    END IF;

    SELECT p.full_name
      INTO v_new_owner_name
      FROM public.profiles AS p
     WHERE p.id = p_new_owner_id
       AND p.role = 'store_owner'
       AND p.is_active IS TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The new owner must be an active store owner';
    END IF;

    SELECT p.full_name
      INTO v_previous_owner_name
      FROM public.profiles AS p
     WHERE p.id = v_previous_owner_id;

    SELECT p.full_name
      INTO v_admin_name
      FROM public.profiles AS p
     WHERE p.id = v_admin_id;

    UPDATE public.stores
       SET owner_id = p_new_owner_id
     WHERE id = p_store_id;

    INSERT INTO public.store_ownership_transfers (
        store_id,
        store_name_at_transfer,
        previous_owner_id,
        previous_owner_name_at_transfer,
        new_owner_id,
        new_owner_name_at_transfer,
        transferred_by,
        transferred_by_name
    )
    VALUES (
        p_store_id,
        v_store_name,
        v_previous_owner_id,
        v_previous_owner_name,
        p_new_owner_id,
        v_new_owner_name,
        v_admin_id,
        v_admin_name
    );

    RETURN jsonb_build_object(
        'success', true,
        'store_id', p_store_id,
        'store_name', v_store_name,
        'previous_owner_id', v_previous_owner_id,
        'new_owner_id', p_new_owner_id
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.transfer_store_ownership(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.transfer_store_ownership(uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.transfer_store_ownership(uuid, uuid) TO authenticated;
