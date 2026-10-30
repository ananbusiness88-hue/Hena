CREATE OR REPLACE FUNCTION private.protect_order_store_part_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.order_id IS DISTINCT FROM OLD.order_id
     OR NEW.store_id IS DISTINCT FROM OLD.store_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Store portion protected fields cannot be changed';
  END IF;

  IF (
       NEW.subtotal IS DISTINCT FROM OLD.subtotal
       OR NEW.item_count IS DISTINCT FROM OLD.item_count
     )
     AND current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Store portion protected fields cannot be changed';
  END IF;

  NEW.ready_at := OLD.ready_at;
  NEW.picked_up_at := OLD.picked_up_at;
  NEW.updated_at := now();

  IF NEW.status = 'ready' AND OLD.status IS DISTINCT FROM 'ready' THEN
    NEW.ready_at := COALESCE(OLD.ready_at, now());
  END IF;

  IF NEW.status = 'picked_up' AND OLD.status IS DISTINCT FROM 'picked_up' THEN
    NEW.picked_up_at := COALESCE(OLD.picked_up_at, now());
  END IF;

  RETURN NEW;
END;
$function$;
