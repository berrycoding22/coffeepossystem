-- CoffeeFlow POS · Phase 16: Damaged and expired inventory handling.
-- Run after 202610300014_phase15_supplier_payments.sql.

create table if not exists public.inventory_wastes (
  id uuid primary key default gen_random_uuid(),
  warehouse_id uuid not null references public.warehouses(id),
  ingredient_id uuid not null references public.ingredients(id),
  quantity numeric(14,3) not null check(quantity > 0),
  reason text not null check(reason in ('damaged', 'expired', 'spillage', 'quality_issue', 'other')),
  note text,
  recorded_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists inventory_wastes_created_idx on public.inventory_wastes(created_at desc);
alter table public.inventory_wastes enable row level security;
create policy "managers manage inventory waste" on public.inventory_wastes for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());

create or replace function public.record_inventory_waste(p_warehouse_id uuid, p_ingredient_id uuid, p_quantity numeric, p_reason text, p_note text default null)
returns public.inventory_wastes language plpgsql security definer set search_path = public as $$
declare v_stock public.warehouse_stocks%rowtype; v_waste public.inventory_wastes%rowtype;
begin
  if not public.can_manage_catalog() then raise exception 'Manager permission required'; end if;
  if p_quantity <= 0 then raise exception 'Quantity must be positive'; end if;
  if p_reason not in ('damaged', 'expired', 'spillage', 'quality_issue', 'other') then raise exception 'Invalid waste reason'; end if;
  select * into v_stock from public.warehouse_stocks where warehouse_id = p_warehouse_id and ingredient_id = p_ingredient_id for update;
  if v_stock.warehouse_id is null or v_stock.quantity < p_quantity then raise exception 'Insufficient warehouse stock'; end if;
  update public.warehouse_stocks set quantity = quantity - p_quantity, updated_at = now() where warehouse_id = p_warehouse_id and ingredient_id = p_ingredient_id;
  update public.ingredients set stock_quantity = stock_quantity - p_quantity where id = p_ingredient_id;
  insert into public.inventory_wastes(warehouse_id, ingredient_id, quantity, reason, note, recorded_by) values(p_warehouse_id, p_ingredient_id, p_quantity, p_reason, nullif(trim(p_note), ''), auth.uid()) returning * into v_waste;
  insert into public.inventory_movements(ingredient_id, warehouse_id, movement_type, quantity, reference_type, reference_id, note, created_by) values(p_ingredient_id, p_warehouse_id, 'waste', -p_quantity, 'inventory_waste', v_waste.id, p_reason || coalesce(': ' || nullif(trim(p_note), ''), ''), auth.uid());
  return v_waste;
end; $$;
grant select on public.inventory_wastes to authenticated;
grant execute on function public.record_inventory_waste(uuid, uuid, numeric, text, text) to authenticated;
