-- CoffeeFlow POS · Phase 19: Sales orders and delivery tracking.
-- Run after 202610300017_phase18_purchase_returns.sql.

do $$ begin create type public.sales_order_status as enum ('draft', 'confirmed', 'delivered', 'cancelled'); exception when duplicate_object then null; end $$;
create table if not exists public.sales_orders (
  id uuid primary key default gen_random_uuid(),
  sales_order_number text not null unique,
  customer_id uuid references public.customers(id) on delete set null,
  branch_id uuid references public.branches(id) on delete set null,
  status public.sales_order_status not null default 'draft',
  subtotal numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null default 0,
  delivery_address text,
  delivery_note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  delivered_at timestamptz
);
create table if not exists public.sales_order_items (
  id uuid primary key default gen_random_uuid(),
  sales_order_id uuid not null references public.sales_orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  quantity integer not null check(quantity > 0),
  unit_price numeric(12,2) not null check(unit_price >= 0),
  total_price numeric(12,2) not null check(total_price >= 0)
);
create sequence if not exists public.sales_order_number_sequence;
create index if not exists sales_orders_status_idx on public.sales_orders(status, created_at desc);
alter table public.sales_orders enable row level security;
alter table public.sales_order_items enable row level security;
create policy "staff read sales orders" on public.sales_orders for select to authenticated using (public.is_staff());
create policy "managers manage sales orders" on public.sales_orders for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "staff read sales order items" on public.sales_order_items for select to authenticated using (public.is_staff());
create policy "managers manage sales order items" on public.sales_order_items for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());

create or replace function public.create_sales_order(p_customer_id uuid, p_items jsonb, p_delivery_address text default null, p_delivery_note text default null)
returns public.sales_orders language plpgsql security definer set search_path = public as $$
declare v_profile public.profiles%rowtype; v_order public.sales_orders%rowtype; v_item jsonb; v_product public.products%rowtype; v_quantity integer; v_total numeric(12,2) := 0;
begin
  select * into v_profile from public.profiles where id = auth.uid() and is_active;
  if v_profile.id is null then raise exception 'Active staff account required'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Add at least one item'; end if;
  if p_customer_id is not null and not exists(select 1 from public.customers where id = p_customer_id and is_active) then raise exception 'Customer not found'; end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_quantity := (v_item ->> 'quantity')::integer; select * into v_product from public.products where id = (v_item ->> 'product_id')::uuid and is_active and is_available;
    if v_product.id is null or v_quantity is null or v_quantity < 1 then raise exception 'Invalid sales order item'; end if;
    v_total := v_total + v_product.base_price * v_quantity;
  end loop;
  insert into public.sales_orders(sales_order_number, customer_id, branch_id, status, subtotal, total_amount, delivery_address, delivery_note, created_by)
  values('SO-' || to_char(current_date, 'YYYYMMDD') || '-' || lpad(nextval('public.sales_order_number_sequence')::text, 5, '0'), p_customer_id, v_profile.branch_id, 'confirmed', v_total, v_total, nullif(trim(p_delivery_address), ''), nullif(trim(p_delivery_note), ''), auth.uid()) returning * into v_order;
  for v_item in select value from jsonb_array_elements(p_items) loop
    select * into v_product from public.products where id = (v_item ->> 'product_id')::uuid; v_quantity := (v_item ->> 'quantity')::integer;
    insert into public.sales_order_items(sales_order_id, product_id, product_name, quantity, unit_price, total_price) values(v_order.id, v_product.id, v_product.name, v_quantity, v_product.base_price, v_product.base_price * v_quantity);
  end loop;
  return v_order;
end; $$;
create or replace function public.mark_sales_order_delivered(p_sales_order_id uuid)
returns public.sales_orders language plpgsql security definer set search_path = public as $$
declare v_order public.sales_orders%rowtype;
begin
  if not public.can_manage_catalog() then raise exception 'Manager permission required'; end if;
  select * into v_order from public.sales_orders where id = p_sales_order_id for update;
  if v_order.id is null then raise exception 'Sales order not found'; end if;
  if v_order.status <> 'confirmed' then raise exception 'Only confirmed sales orders can be delivered'; end if;
  update public.sales_orders set status = 'delivered', delivered_at = now() where id = p_sales_order_id returning * into v_order;
  return v_order;
end; $$;
grant execute on function public.create_sales_order(uuid, jsonb, text, text), public.mark_sales_order_delivered(uuid) to authenticated;
