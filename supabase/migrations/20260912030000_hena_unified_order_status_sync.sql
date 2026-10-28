BEGIN;

CREATE OR REPLACE FUNCTION public.protect_order_mutations()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
  v_role public.user_role := public.current_user_role();
  v_all_parts_picked_up boolean := false;
BEGIN
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF v_role = 'store_owner'
     AND OLD.status IS DISTINCT FROM NEW.status
     AND NEW.status = 'out_for_delivery'::public.order_status
  THEN
    SELECT
      EXISTS (
        SELECT 1
        FROM public.order_store_parts osp
        WHERE osp.order_id = NEW.id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.order_store_parts osp
        WHERE osp.order_id = NEW.id
          AND osp.status <> 'picked_up'::public.store_order_part_status
      )
    INTO v_all_parts_picked_up;

    IF v_all_parts_picked_up THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Order can move to out_for_delivery only when all store portions are picked_up';
  END IF;

  IF v_role = 'customer' THEN
    IF NEW.customer_id IS DISTINCT FROM OLD.customer_id
       OR NEW.store_id IS DISTINCT FROM OLD.store_id
       OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
       OR NEW.subtotal IS DISTINCT FROM OLD.subtotal
       OR NEW.delivery_fee IS DISTINCT FROM OLD.delivery_fee
       OR NEW.extra_fee IS DISTINCT FROM OLD.extra_fee
       OR NEW.customer_notes IS DISTINCT FROM OLD.customer_notes
       OR NEW.delivery_points IS DISTINCT FROM OLD.delivery_points
       OR NEW.delivery_recipient_name IS DISTINCT FROM OLD.delivery_recipient_name
       OR NEW.delivery_phone IS DISTINCT FROM OLD.delivery_phone
       OR NEW.delivery_governorate IS DISTINCT FROM OLD.delivery_governorate
       OR NEW.delivery_city IS DISTINCT FROM OLD.delivery_city
       OR NEW.delivery_area IS DISTINCT FROM OLD.delivery_area
       OR NEW.delivery_building_number IS DISTINCT FROM OLD.delivery_building_number
       OR NEW.delivery_apartment_number IS DISTINCT FROM OLD.delivery_apartment_number
       OR NEW.delivery_address_details IS DISTINCT FROM OLD.delivery_address_details
    THEN
      RAISE EXCEPTION 'Customers cannot modify order data';
    END IF;

    IF NEW.status <> 'cancelled' AND NEW.status <> OLD.status THEN
      RAISE EXCEPTION 'Customers can only cancel an order';
    END IF;

    RETURN NEW;
  END IF;

  IF v_role = 'store_owner' THEN
    IF NEW.customer_id IS DISTINCT FROM OLD.customer_id
       OR NEW.store_id IS DISTINCT FROM OLD.store_id
       OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
       OR NEW.subtotal IS DISTINCT FROM OLD.subtotal
       OR NEW.delivery_fee IS DISTINCT FROM OLD.delivery_fee
       OR NEW.extra_fee IS DISTINCT FROM OLD.extra_fee
       OR NEW.customer_notes IS DISTINCT FROM OLD.customer_notes
       OR NEW.delivery_points IS DISTINCT FROM OLD.delivery_points
       OR NEW.delivery_recipient_name IS DISTINCT FROM OLD.delivery_recipient_name
       OR NEW.delivery_phone IS DISTINCT FROM OLD.delivery_phone
       OR NEW.delivery_governorate IS DISTINCT FROM OLD.delivery_governorate
       OR NEW.delivery_city IS DISTINCT FROM OLD.delivery_city
       OR NEW.delivery_area IS DISTINCT FROM OLD.delivery_area
       OR NEW.delivery_building_number IS DISTINCT FROM OLD.delivery_building_number
       OR NEW.delivery_apartment_number IS DISTINCT FROM OLD.delivery_apartment_number
       OR NEW.delivery_address_details IS DISTINCT FROM OLD.delivery_address_details
    THEN
      RAISE EXCEPTION 'Store owners cannot modify protected order fields';
    END IF;

    IF NEW.status NOT IN (
         'confirmed',
         'preparing',
         'ready',
         'cancelled'
       )
       AND NEW.status <> OLD.status
    THEN
      RAISE EXCEPTION 'Invalid store order status transition';
    END IF;

    RETURN NEW;
  END IF;

  IF v_role = 'driver' THEN
    IF NEW.customer_id IS DISTINCT FROM OLD.customer_id
       OR NEW.store_id IS DISTINCT FROM OLD.store_id
       OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
       OR NEW.subtotal IS DISTINCT FROM OLD.subtotal
       OR NEW.delivery_fee IS DISTINCT FROM OLD.delivery_fee
       OR NEW.extra_fee IS DISTINCT FROM OLD.extra_fee
       OR NEW.customer_notes IS DISTINCT FROM OLD.customer_notes
       OR NEW.delivery_points IS DISTINCT FROM OLD.delivery_points
       OR NEW.delivery_recipient_name IS DISTINCT FROM OLD.delivery_recipient_name
       OR NEW.delivery_phone IS DISTINCT FROM OLD.delivery_phone
       OR NEW.delivery_governorate IS DISTINCT FROM OLD.delivery_governorate
       OR NEW.delivery_city IS DISTINCT FROM OLD.delivery_city
       OR NEW.delivery_area IS DISTINCT FROM OLD.delivery_area
       OR NEW.delivery_building_number IS DISTINCT FROM OLD.delivery_building_number
       OR NEW.delivery_apartment_number IS DISTINCT FROM OLD.delivery_apartment_number
       OR NEW.delivery_address_details IS DISTINCT FROM OLD.delivery_address_details
    THEN
      RAISE EXCEPTION 'Drivers cannot modify protected order fields';
    END IF;

    IF NEW.status NOT IN (
         'assigned',
         'picked_up',
         'out_for_delivery'
       )
       AND NEW.status <> OLD.status
    THEN
      RAISE EXCEPTION 'Invalid driver order status transition';
    END IF;

    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Unauthorized order mutation';
END;
$function$;


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
BEGIN
    v_order_id := NEW.order_id;

    SELECT o.status
    INTO v_current_status
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

    IF v_picked_parts = v_total_parts
       AND v_current_status <> 'out_for_delivery'::public.order_status
       AND v_current_status <> 'delivered'::public.order_status
       AND v_current_status <> 'cancelled'::public.order_status
    THEN
        UPDATE public.orders
        SET status = 'out_for_delivery'::public.order_status
        WHERE id = v_order_id;

        RETURN NEW;
    END IF;

    IF v_ready_or_picked_parts = v_total_parts
       AND v_current_status NOT IN (
           'ready'::public.order_status,
           'out_for_delivery'::public.order_status,
           'delivered'::public.order_status,
           'cancelled'::public.order_status
       )
    THEN
        UPDATE public.orders
        SET status = 'ready'::public.order_status
        WHERE id = v_order_id;
    END IF;

    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS trigger_sync_unified_order_status_from_parts
ON public.order_store_parts;

CREATE TRIGGER trigger_sync_unified_order_status_from_parts
AFTER UPDATE OF status
ON public.order_store_parts
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION private.sync_unified_order_status_from_parts();

COMMENT ON FUNCTION private.sync_unified_order_status_from_parts()
IS 'Synchronizes Unified Order status from Store Portion statuses: all ready => ready, all picked_up => out_for_delivery.';

COMMIT;
