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

  /*
    Driver assignment:
    The SECURITY DEFINER driver_accept_order() may atomically assign
    an unassigned ready order to the authenticated driver.
    Direct client UPDATE remains blocked by RLS.
  */
  IF v_role = 'driver'
     AND OLD.driver_id IS NULL
     AND NEW.driver_id = auth.uid()
     AND OLD.status = 'ready'::public.order_status
     AND NEW.status = 'assigned'::public.order_status
  THEN
    IF NEW.customer_id IS DISTINCT FROM OLD.customer_id
       OR NEW.store_id IS DISTINCT FROM OLD.store_id
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
      RAISE EXCEPTION 'Driver assignment cannot modify protected order fields';
    END IF;

    RETURN NEW;
  END IF;

  /*
    Automatic Unified Order transition:
    allow out_for_delivery only when all Store Portions are picked_up.
  */
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

  /*
    Final delivery transition:
    only the assigned driver may move out_for_delivery -> delivered.
  */
  IF v_role = 'driver'
     AND OLD.status = 'out_for_delivery'::public.order_status
     AND NEW.status = 'delivered'::public.order_status
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

    RAISE EXCEPTION 'Order cannot be delivered until all store portions are picked_up';
  END IF;

  /*
    Customer: cancellation only.
  */
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

  /*
    Store owners: status changes only.
  */
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

  /*
    Driver: delivery status only.
  */
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
         'out_for_delivery',
         'delivered'
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

COMMIT;
