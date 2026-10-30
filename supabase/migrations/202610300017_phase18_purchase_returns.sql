-- CoffeeFlow POS · Phase 18: Purchase returns and supplier debit notes.
-- Run after 202610300016_phase17_sales_returns.sql.

alter table public.purchases add column if not exists return_amount numeric(12,2) not null default 0 check(return_amount >= 0);
create table if not exists public.purchase_returns (
  id uuid primary key default gen_random_uuid(),
  return_number text not null unique,
  purchase_id uuid not null references public.purchases(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id),
  total_amount numeric(12,2) not null default 0 check(total_amount >= 0),
  reason text,
  processed_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create table if not exists public.purchase_return_items (
  id uuid primary key default gen_random_uuid(),
  purchase_return_id uuid not null references public.purchase_returns(id) on delete cascade,
  purchase_item_id uuid not null references public.purchase_items(id),
  ingredient_id uuid not null references public.ingredients(id),
  quantity numeric(14,3) not null check(quantity > 0),
  unit_cost numeric(12,4) not null check(unit_cost >= 0)
);
create sequence if not exists public.purchase_return_number_sequence;
create index if not exists purchase_returns_purchase_idx on public.purchase_returns(purchase_id, created_at desc);
alter table public.purchase_returns enable row level security;
alter table public.purchase_return_items enable row level security;
create policy "managers manage purchase returns" on public.purchase_returns for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "managers manage purchase return items" on public.purchase_return_items for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());

create or replace function public.return_purchase_items(p_purchase_id uuid, p_items jsonb, p_reason text default null)
returns public.purchase_returns language plpgsql security definer set search_path = public as $$
declare v_purchase public.purchases%rowtype; v_return public.purchase_returns%rowtype; v_item jsonb; v_purchase_item public.purchase_items%rowtype; v_quantity numeric(14,3); v_returned numeric(14,3); v_stock public.warehouse_stocks%rowtype; v_total numeric(12,2) := 0;
begin
  if not public.can_manage_catalog() then raise exception 'Manager permission required'; end if;
  select * into v_purchase from public.purchases where id = p_purchase_id for update;
  if v_purchase.id is null or v_purchase.status <> 'received' then raise exception 'Only received purchase orders can be returned'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Add at least one return item'; end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_quantity := (v_item ->> 'quantity')::numeric;
    select * into v_purchase_item from public.purchase_items where id = (v_item ->> 'purchase_item_id')::uuid and purchase_id = p_purchase_id for update;
    if v_purchase_item.id is null or v_quantity is null or v_quantity <= 0 then raise exception 'Invalid purchase return item'; end if;
    select coalesce(sum(pri.quantity), 0) into v_returned from public.purchase_return_items pri join public.purchase_returns pr on pr.id = pri.purchase_return_id where pri.purchase_item_id = v_purchase_item.id;
    if v_quantity > v_purchase_item.received_quantity - v_returned then raise exception 'Return quantity exceeds received quantity'; end if;
    select * into v_stock from public.warehouse_stocks where warehouse_id = v_purchase.warehouse_id and ingredient_id = v_purchase_item.ingredient_id for update;
    if v_stock.warehouse_id is null or v_stock.quantity < v_quantity then raise exception 'Insufficient warehouse stock for return'; end if;
    v_total := v_total + v_quantity * v_purchase_item.unit_cost;
  end loop;
  insert into public.purchase_returns(return_number, purchase_id, warehouse_id, total_amount, reason, processed_by)
  values('PR-' || to_char(current_date, 'YYYYMMDD') || '-' || lpad(nextval('public.purchase_return_number_sequence')::text, 5, '0'), p_purchase_id, v_purchase.warehouse_id, v_total, nullif(trim(p_reason), ''), auth.uid()) returning * into v_return;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_quantity := (v_item ->> 'quantity')::numeric;
    select * into v_purchase_item from public.purchase_items where id = (v_item ->> 'purchase_item_id')::uuid;
    insert into public.purchase_return_items(purchase_return_id, purchase_item_id, ingredient_id, quantity, unit_cost) values(v_return.id, v_purchase_item.id, v_purchase_item.ingredient_id, v_quantity, v_purchase_item.unit_cost);
    update public.warehouse_stocks set quantity = quantity - v_quantity, updated_at = now() where warehouse_id = v_purchase.warehouse_id and ingredient_id = v_purchase_item.ingredient_id;
    update public.ingredients set stock_quantity = stock_quantity - v_quantity where id = v_purchase_item.ingredient_id;
    insert into public.inventory_movements(ingredient_id, warehouse_id, movement_type, quantity, reference_type, reference_id, note, created_by) values(v_purchase_item.ingredient_id, v_purchase.warehouse_id, 'stock_out', -v_quantity, 'purchase_return', v_return.id, 'Purchase return to supplier', auth.uid());
  end loop;
  update public.purchases set return_amount = return_amount + v_total, payment_status = case when amount_paid >= total_amount - return_amount - v_total then 'paid' else payment_status end where id = p_purchase_id;
  return v_return;
end; $$;

create or replace function public.record_supplier_payment(p_purchase_id uuid, p_amount numeric, p_method text default 'cash_usd', p_note text default null)
returns public.purchases language plpgsql security definer set search_path = public as $$
declare v_purchase public.purchases%rowtype; v_due numeric(12,2);
begin
  if not public.can_manage_catalog() then raise exception 'Manager permission required'; end if;
  if p_amount <= 0 then raise exception 'Payment amount must be positive'; end if;
  if p_method not in ('cash_usd', 'cash_khr', 'khqr', 'bank_transfer') then raise exception 'Invalid payment method'; end if;
  select * into v_purchase from public.purchases where id = p_purchase_id for update;
  if v_purchase.id is null then raise exception 'Purchase order not found'; end if;
  if v_purchase.status <> 'received' then raise exception 'Receive stock before paying this bill'; end if;
  v_due := greatest(0, v_purchase.total_amount - v_purchase.return_amount - v_purchase.amount_paid);
  if p_amount > v_due then raise exception 'Payment exceeds the outstanding bill amount'; end if;
  insert into public.supplier_payments(purchase_id, supplier_id, amount, method, note, recorded_by) values(v_purchase.id, v_purchase.supplier_id, p_amount, p_method, nullif(trim(p_note), ''), auth.uid());
  update public.purchases set amount_paid = amount_paid + p_amount, payment_status = case when amount_paid + p_amount >= total_amount - return_amount then 'paid' else 'partial' end where id = v_purchase.id returning * into v_purchase;
  return v_purchase;
end; $$;
grant select on public.purchase_returns, public.purchase_return_items to authenticated;
grant execute on function public.return_purchase_items(uuid, jsonb, text), public.record_supplier_payment(uuid, numeric, text, text) to authenticated;
