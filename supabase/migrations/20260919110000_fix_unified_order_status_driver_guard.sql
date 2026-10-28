BEGIN;

CREATE OR REPLACE FUNCTION private.sync_unified_order_status_from_parts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_order_id uuid;
    v_total_parts integer;
    v_ready_or_picked_parts integer;
    v_picked_parts integer;
    v_current_status public.order_status;
    v_driver_id uuid;
BEGIN
    v_order_id := NEW.order_id;

    SELECT
        o.status,
        o.driver_id
    INTO
        v_current_status,
        v_driver_id
    FROM public.orders AS o
    WHERE o.id = v_order_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (
            WHERE osp.status IN (
                'ready'::public.store_order_part_status,
                'picked_up'::public.store_order_part_status
            )
        ),
        COUNT(*) FILTER (
            WHERE osp.status = 'picked_up'::public.store_order_part_status
        )
    INTO
        v_total_parts,
        v_ready_or_picked_parts,
        v_picked_parts
    FROM public.order_store_parts AS osp
    WHERE osp.order_id = v_order_id;

    IF v_total_parts = 0 THEN
        RETURN NEW;
    END IF;

    /*
      All portions picked up:
      Unified Order moves to out_for_delivery
      only after a driver has been assigned.
    */
    IF v_picked_parts = v_total_parts
       AND v_driver_id IS NOT NULL
       AND v_current_status NOT IN (
           'out_for_delivery'::public.order_status,
           'delivered'::public.order_status,
           'cancelled'::public.order_status
       )
    THEN
        UPDATE public.orders
        SET status = 'out_for_delivery'::public.order_status
        WHERE id = v_order_id;

        RETURN NEW;
    END IF;

    /*
      Move to ready only from the pre-driver preparation stages.
      Never move assigned orders backwards to ready.
    */
    IF v_ready_or_picked_parts = v_total_parts
       AND v_current_status IN (
           'pending'::public.order_status,
           'preparing'::public.order_status
       )
    THEN
        UPDATE public.orders
        SET status = 'ready'::public.order_status
        WHERE id = v_order_id;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION private.sync_unified_order_status_from_parts()
IS 'Synchronizes Unified Order status from Store Portion statuses: all ready => ready, all picked_up + assigned driver => out_for_delivery.';

COMMIT;
