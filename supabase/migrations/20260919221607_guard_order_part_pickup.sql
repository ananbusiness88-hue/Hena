-- Protect store-order-part pickup transition.
-- Store Owner may mark only preparing -> ready.
-- Driver may mark ready -> picked_up only for the assigned order.
-- Admin remains allowed for administrative corrections.

create or replace function public.guard_order_part_pickup()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
declare
  v_role public.user_role := public.current_user_role();
begin
  if old.status is distinct from new.status
     and new.status = 'picked_up'::public.store_order_part_status
  then

    if v_role = 'store_owner' then
      raise exception
        'Store owner cannot mark order part as picked_up; driver pickup confirmation is required';
    end if;

    if v_role = 'driver' then
      if not exists (
        select 1
        from public.orders o
        where o.id = new.order_id
          and o.driver_id = auth.uid()
      ) then
        raise exception
          'Only the assigned driver can mark this order part as picked_up';
      end if;
    end if;

  end if;

  return new;
end;
$function$;

drop trigger if exists trg_guard_order_part_pickup
on public.order_store_parts;

create trigger trg_guard_order_part_pickup
before update of status
on public.order_store_parts
for each row
execute function public.guard_order_part_pickup();
