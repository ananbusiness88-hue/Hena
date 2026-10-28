-- Store Owner may only mark a store order part as ready.
-- Driver pickup remains a separate responsibility.
-- Admin may perform administrative corrections.

create or replace function public.store_owner_update_order_part_status(
  p_part_id uuid,
  p_status public.store_order_part_status
)
returns void
language plpgsql
set search_path to 'public'
as $function$
declare
  v_role public.user_role := public.current_user_role();
begin
  if v_role not in ('store_owner', 'admin') then
    raise exception 'Store owner privileges required';
  end if;

  if v_role = 'store_owner'
     and p_status <> 'ready'::public.store_order_part_status
  then
    raise exception
      'Store owner may only mark order portions as ready';
  end if;

  update public.order_store_parts osp
  set status = p_status,
      updated_at = now()
  where osp.id = p_part_id
    and (
      public.is_admin()
      or exists (
        select 1
        from public.stores s
        where s.id = osp.store_id
          and s.owner_id = auth.uid()
      )
    );

  if not found then
    raise exception 'Order portion not found or access denied';
  end if;
end;
$function$;
