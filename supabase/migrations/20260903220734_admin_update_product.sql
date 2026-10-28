create or replace function public.admin_update_product(
  p_product_id uuid,
  p_category_id uuid,
  p_name text,
  p_description text default null,
  p_price numeric default null,
  p_selling_method public.selling_method default 'unit',
  p_selling_value numeric default 1,
  p_is_active boolean default true,
  p_pricing jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_store_id uuid;
  v_item jsonb;
  v_pricing_type public.product_pricing_type;
  v_fraction_value numeric;
  v_quantity numeric;
  v_price numeric;
  v_unit_name text;
  v_sort_order integer := 0;
begin
  if (select auth.uid()) is null
     or not public.is_admin() then
    raise exception 'Admin privileges required';
  end if;

  if trim(coalesce(p_name, '')) = '' then
    raise exception 'Product name is required';
  end if;

  if p_price is null or p_price <= 0 then
    raise exception 'Product price must be greater than zero';
  end if;

  if p_selling_value is null or p_selling_value <= 0 then
    raise exception 'Selling value must be greater than zero';
  end if;

  if p_pricing is null
     or jsonb_typeof(p_pricing) <> 'array'
     or jsonb_array_length(p_pricing) = 0 then
    raise exception 'At least one pricing option is required';
  end if;

  select store_id
    into v_store_id
  from public.products
  where id = p_product_id
  for update;

  if v_store_id is null then
    raise exception 'Product not found';
  end if;

  if not exists (
    select 1
    from public.product_categories pc
    where pc.id = p_category_id
      and pc.store_id = v_store_id
      and pc.is_active = true
  ) then
    raise exception 'Product category does not belong to the same active store';
  end if;

  update public.products
  set
    category_id = p_category_id,
    name = trim(p_name),
    description = nullif(trim(coalesce(p_description, '')), ''),
    price = p_price,
    selling_method = p_selling_method,
    selling_value = p_selling_value,
    is_active = p_is_active,
    updated_at = now()
  where id = p_product_id;

  delete from public.product_pricing
  where product_id = p_product_id;

  for v_item in
    select value
    from jsonb_array_elements(p_pricing)
  loop
    v_pricing_type :=
      (v_item ->> 'pricing_type')::public.product_pricing_type;

    v_unit_name := nullif(trim(v_item ->> 'unit_name'), '');
    v_quantity := nullif(v_item ->> 'quantity', '')::numeric;
    v_price := nullif(v_item ->> 'price', '')::numeric;
    v_fraction_value :=
      nullif(v_item ->> 'fraction_value', '')::numeric;

    if v_price is null or v_price <= 0 then
      raise exception 'Pricing option price must be greater than zero';
    end if;

    if v_pricing_type in ('unit', 'weight') then

      if v_unit_name is null then
        raise exception 'Unit name is required for unit/weight pricing';
      end if;

      if v_quantity is null or v_quantity <= 0 then
        raise exception 'Quantity must be greater than zero';
      end if;

      if v_fraction_value is not null then
        raise exception 'Fraction value must be null for unit/weight pricing';
      end if;

    elsif v_pricing_type = 'value' then

      if v_unit_name is not null
         or v_quantity is not null
         or v_fraction_value is not null then
        raise exception 'Value pricing cannot contain unit, quantity or fraction fields';
      end if;

    elsif v_pricing_type = 'fraction' then

      if v_fraction_value is null
         or v_fraction_value <= 0
         or v_fraction_value > 1 then
        raise exception 'Fraction value must be greater than 0 and less than or equal to 1';
      end if;

      if v_unit_name is not null
         or v_quantity is not null then
        raise exception 'Fraction pricing cannot contain unit or quantity fields';
      end if;

    end if;

    insert into public.product_pricing (
      product_id,
      pricing_type,
      unit_name,
      quantity,
      price,
      fraction_value,
      is_active,
      sort_order
    )
    values (
      p_product_id,
      v_pricing_type,
      v_unit_name,
      v_quantity,
      v_price,
      v_fraction_value,
      coalesce((v_item ->> 'is_active')::boolean, true),
      v_sort_order
    );

    v_sort_order := v_sort_order + 1;
  end loop;

  return p_product_id;
end;
$$;

revoke all
on function public.admin_update_product(
  uuid,
  uuid,
  text,
  text,
  numeric,
  public.selling_method,
  numeric,
  boolean,
  jsonb
)
from public;

grant execute
on function public.admin_update_product(
  uuid,
  uuid,
  text,
  text,
  numeric,
  public.selling_method,
  numeric,
  boolean,
  jsonb
)
to authenticated;