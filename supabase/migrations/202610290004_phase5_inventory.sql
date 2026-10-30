-- CoffeeFlow POS · Phase 5 inventory and recipe transactions.
create table if not exists public.suppliers (id uuid primary key default gen_random_uuid(), name text not null, phone text, email text, address text, is_active boolean not null default true, created_at timestamptz not null default now());
create table if not exists public.purchases (id uuid primary key default gen_random_uuid(), supplier_id uuid references public.suppliers(id) on delete set null, purchase_number text not null unique, total_amount numeric(12,2) not null default 0, received_at timestamptz not null default now(), created_by uuid references public.profiles(id), note text);
create table if not exists public.purchase_items (id uuid primary key default gen_random_uuid(), purchase_id uuid not null references public.purchases(id) on delete cascade, ingredient_id uuid not null references public.ingredients(id), quantity numeric(14,3) not null check(quantity > 0), unit_cost numeric(12,4) not null default 0);
create table if not exists public.refunds (id uuid primary key default gen_random_uuid(), order_id uuid not null unique references public.orders(id), amount numeric(12,2) not null check(amount >= 0), reason text, processed_by uuid references public.profiles(id), created_at timestamptz not null default now());
create unique index if not exists inventory_order_sale_once on public.inventory_movements(ingredient_id, reference_type, reference_id) where reference_type = 'order_sale';
create unique index if not exists inventory_order_restore_once on public.inventory_movements(ingredient_id, reference_type, reference_id) where reference_type = 'order_refund_restore';
alter table public.suppliers enable row level security; alter table public.purchases enable row level security; alter table public.purchase_items enable row level security; alter table public.refunds enable row level security;
create policy "managers manage suppliers" on public.suppliers for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "managers manage purchases" on public.purchases for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "managers manage purchase items" on public.purchase_items for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "managers read refunds" on public.refunds for select to authenticated using (public.can_manage_catalog());

create or replace function public.receive_inventory(p_ingredient_id uuid, p_quantity numeric, p_note text default null)
returns public.ingredients language plpgsql security definer set search_path = public as $$
declare v_ingredient public.ingredients%rowtype;
begin
  if not public.can_manage_catalog() then raise exception 'Manager permission required'; end if;
  if p_quantity = 0 then raise exception 'Quantity must not be zero'; end if;
  select * into v_ingredient from public.ingredients where id = p_ingredient_id for update;
  if v_ingredient.id is null then raise exception 'Ingredient not found'; end if;
  update public.ingredients set stock_quantity = stock_quantity + p_quantity where id = p_ingredient_id returning * into v_ingredient;
  insert into public.inventory_movements (ingredient_id, movement_type, quantity, note, created_by) values (p_ingredient_id, case when p_quantity > 0 then 'stock_in' else 'adjustment' end, p_quantity, nullif(trim(p_note), ''), auth.uid());
  return v_ingredient;
end; $$;

create or replace function public.apply_order_inventory(p_order_id uuid) returns void language plpgsql security definer set search_path = public as $$
declare v record; v_ingredient public.ingredients%rowtype;
begin
  for v in select r.ingredient_id, sum(r.quantity * oi.quantity) as quantity from public.order_items oi join public.recipes r on r.product_id = oi.product_id where oi.order_id = p_order_id group by r.ingredient_id loop
    select * into v_ingredient from public.ingredients where id = v.ingredient_id for update;
    if v_ingredient.stock_quantity < v.quantity then raise exception 'Insufficient stock for %', v_ingredient.name; end if;
    insert into public.inventory_movements (ingredient_id, movement_type, quantity, reference_type, reference_id, note, created_by) values (v.ingredient_id, 'sale_deduction', -v.quantity, 'order_sale', p_order_id, 'Automatic sale deduction', auth.uid()) on conflict (ingredient_id, reference_type, reference_id) where reference_type = 'order_sale' do nothing;
    if found then update public.ingredients set stock_quantity = stock_quantity - v.quantity where id = v.ingredient_id; end if;
  end loop;
end; $$;

create or replace function public.refund_completed_order(p_order_id uuid, p_reason text default null) returns void language plpgsql security definer set search_path = public as $$
declare v_profile public.profiles%rowtype; v_order public.orders%rowtype; v record;
begin
  select * into v_profile from public.profiles where id = auth.uid() and is_active;
  if v_profile.role not in ('super_admin','manager') then raise exception 'Manager permission required'; end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.status <> 'completed' then raise exception 'Only completed orders can be refunded'; end if;
  if exists(select 1 from public.refunds where order_id = p_order_id) then raise exception 'Order was already refunded'; end if;
  for v in select ingredient_id, -quantity as quantity from public.inventory_movements where reference_type = 'order_sale' and reference_id = p_order_id loop
    update public.ingredients set stock_quantity = stock_quantity + v.quantity where id = v.ingredient_id;
    insert into public.inventory_movements (ingredient_id, movement_type, quantity, reference_type, reference_id, note, created_by) values (v.ingredient_id, 'refund_restore', v.quantity, 'order_refund_restore', p_order_id, 'Automatic refund restoration', auth.uid());
  end loop;
  insert into public.refunds(order_id, amount, reason, processed_by) values(p_order_id, v_order.total_amount, nullif(trim(p_reason), ''), auth.uid());
  update public.orders set status = 'cancelled' where id = p_order_id;
end; $$;

create or replace function public.set_order_status(p_order_id uuid, p_status public.order_status) returns public.orders language plpgsql security definer set search_path = public as $$
declare v_profile public.profiles%rowtype; v_order public.orders%rowtype;
begin
  select * into v_profile from public.profiles where id = auth.uid() and is_active;
  if v_profile.id is null then raise exception 'An active staff account is required'; end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.id is null then raise exception 'Order not found'; end if;
  if v_profile.role = 'barista' and p_status not in ('preparing','ready') then raise exception 'Baristas may only set preparing or ready'; end if;
  if v_profile.role = 'cashier' and p_status not in ('completed','cancelled') then raise exception 'Cashiers may only complete or cancel orders'; end if;
  if p_status = 'cancelled' and v_profile.role not in ('super_admin','manager','cashier') then raise exception 'Not permitted to cancel'; end if;
  if v_order.status in ('completed','cancelled') and p_status <> v_order.status then raise exception 'Closed orders cannot be changed'; end if;
  if p_status = 'completed' then perform public.apply_order_inventory(p_order_id); end if;
  update public.orders set status = p_status, completed_at = case when p_status = 'completed' then now() else completed_at end where id = p_order_id returning * into v_order;
  return v_order;
end; $$;
grant execute on function public.receive_inventory(uuid, numeric, text), public.refund_completed_order(uuid, text), public.set_order_status(uuid, public.order_status) to authenticated;
