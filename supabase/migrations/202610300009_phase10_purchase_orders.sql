-- CoffeeFlow POS · Phase 10: Purchase orders and warehouse receiving.
-- Run after 202610300008_phase9_branches_warehouses.sql.

do $$ begin
  create type public.purchase_status as enum ('draft', 'ordered', 'received', 'cancelled');
exception when duplicate_object then null;
end $$;
alter table public.purchases add column if not exists warehouse_id uuid references public.warehouses(id) on delete set null;
alter table public.purchases add column if not exists status public.purchase_status not null default 'draft';
alter table public.purchases add column if not exists created_at timestamptz not null default now();
alter table public.purchases add column if not exists ordered_at timestamptz;
alter table public.purchases add column if not exists received_by uuid references public.profiles(id);
alter table public.purchase_items add column if not exists received_quantity numeric(14,3) not null default 0;
create sequence if not exists public.purchase_number_sequence;
create index if not exists purchases_status_idx on public.purchases(status, created_at desc);
create index if not exists purchases_warehouse_idx on public.purchases(warehouse_id, created_at desc);

create or replace function public.create_purchase_order(p_supplier_id uuid, p_warehouse_id uuid, p_items jsonb, p_note text default null)
returns public.purchases language plpgsql security definer set search_path = public as $$
declare v_purchase public.purchases%rowtype; v_item jsonb; v_ingredient public.ingredients%rowtype; v_quantity numeric(14,3); v_cost numeric(12,4); v_total numeric(12,2) := 0;
begin
  if not public.can_manage_catalog() then raise exception 'Manager permission required'; end if;
  if not exists(select 1 from public.suppliers where id = p_supplier_id and is_active) then raise exception 'Supplier not found'; end if;
  if not exists(select 1 from public.warehouses where id = p_warehouse_id and is_active) then raise exception 'Warehouse not found'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Add at least one purchase item'; end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_quantity := (v_item ->> 'quantity')::numeric; v_cost := (v_item ->> 'unit_cost')::numeric;
    select * into v_ingredient from public.ingredients where id = (v_item ->> 'ingredient_id')::uuid and is_active;
    if v_ingredient.id is null or v_quantity <= 0 or v_cost < 0 then raise exception 'Invalid purchase item'; end if;
    v_total := v_total + (v_quantity * v_cost);
  end loop;
  insert into public.purchases(supplier_id, warehouse_id, purchase_number, total_amount, status, created_by, note)
  values(p_supplier_id, p_warehouse_id, 'PO-' || to_char(current_date, 'YYYYMMDD') || '-' || lpad(nextval('public.purchase_number_sequence')::text, 5, '0'), v_total, 'ordered', auth.uid(), nullif(trim(p_note), '')) returning * into v_purchase;
  for v_item in select value from jsonb_array_elements(p_items) loop
    insert into public.purchase_items(purchase_id, ingredient_id, quantity, unit_cost)
    values(v_purchase.id, (v_item ->> 'ingredient_id')::uuid, (v_item ->> 'quantity')::numeric, (v_item ->> 'unit_cost')::numeric);
  end loop;
  update public.purchases set ordered_at = now() where id = v_purchase.id returning * into v_purchase;
  return v_purchase;
end; $$;

create or replace function public.receive_purchase_order(p_purchase_id uuid)
returns public.purchases language plpgsql security definer set search_path = public as $$
declare v_purchase public.purchases%rowtype; v_item record;
begin
  if not public.can_manage_catalog() then raise exception 'Manager permission required'; end if;
  select * into v_purchase from public.purchases where id = p_purchase_id for update;
  if v_purchase.id is null then raise exception 'Purchase order not found'; end if;
  if v_purchase.status = 'received' then return v_purchase; end if;
  if v_purchase.status <> 'ordered' then raise exception 'Only ordered purchases can be received'; end if;
  for v_item in select * from public.purchase_items where purchase_id = p_purchase_id loop
    insert into public.warehouse_stocks(warehouse_id, ingredient_id, quantity) values(v_purchase.warehouse_id, v_item.ingredient_id, v_item.quantity)
    on conflict (warehouse_id, ingredient_id) do update set quantity = public.warehouse_stocks.quantity + excluded.quantity, updated_at = now();
    update public.ingredients set stock_quantity = stock_quantity + v_item.quantity, cost_per_unit = v_item.unit_cost where id = v_item.ingredient_id;
    update public.purchase_items set received_quantity = quantity where id = v_item.id;
    insert into public.inventory_movements(ingredient_id, warehouse_id, movement_type, quantity, reference_type, reference_id, note, created_by)
    values(v_item.ingredient_id, v_purchase.warehouse_id, 'stock_in', v_item.quantity, 'purchase_receipt', v_purchase.id, 'Purchase receiving', auth.uid());
  end loop;
  update public.purchases set status = 'received', received_at = now(), received_by = auth.uid() where id = p_purchase_id returning * into v_purchase;
  return v_purchase;
end; $$;

grant execute on function public.create_purchase_order(uuid, uuid, jsonb, text), public.receive_purchase_order(uuid) to authenticated;
