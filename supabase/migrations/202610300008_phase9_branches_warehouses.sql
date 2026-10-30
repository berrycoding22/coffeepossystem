-- CoffeeFlow POS · Phase 9: Multi-branch and warehouse foundation.
-- Run after 202610290007_phase8_security_hardening.sql.
-- Existing data is preserved in Main Branch / Main Warehouse.

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  khmer_name text,
  phone text,
  address text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.warehouses (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  code text not null unique,
  name text not null,
  khmer_name text,
  address text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(branch_id, name)
);

create table if not exists public.warehouse_stocks (
  warehouse_id uuid not null references public.warehouses(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id) on delete cascade,
  quantity numeric(14,3) not null default 0,
  updated_at timestamptz not null default now(),
  primary key (warehouse_id, ingredient_id)
);

do $$ begin
  create type public.stock_transfer_status as enum ('draft', 'in_transit', 'completed', 'cancelled');
exception when duplicate_object then null;
end $$;
create table if not exists public.stock_transfers (
  id uuid primary key default gen_random_uuid(),
  transfer_number text not null unique,
  source_warehouse_id uuid not null references public.warehouses(id),
  destination_warehouse_id uuid not null references public.warehouses(id),
  status public.stock_transfer_status not null default 'draft',
  note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  check(source_warehouse_id <> destination_warehouse_id)
);
create table if not exists public.stock_transfer_items (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.stock_transfers(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id),
  quantity numeric(14,3) not null check(quantity > 0),
  unique(transfer_id, ingredient_id)
);

alter table public.profiles add column if not exists branch_id uuid references public.branches(id) on delete set null;
alter table public.orders add column if not exists branch_id uuid references public.branches(id) on delete set null;
alter table public.cafe_tables add column if not exists branch_id uuid references public.branches(id) on delete set null;
alter table public.inventory_movements add column if not exists warehouse_id uuid references public.warehouses(id) on delete set null;

insert into public.branches (code, name, khmer_name)
values ('MAIN', 'Main Branch', 'សាខាចម្បង')
on conflict (code) do nothing;
insert into public.warehouses (branch_id, code, name, khmer_name)
select id, 'MAIN-WH', 'Main Warehouse', 'ឃ្លាំងចម្បង' from public.branches where code = 'MAIN'
on conflict (code) do nothing;

update public.profiles set branch_id = (select id from public.branches where code = 'MAIN') where branch_id is null;
update public.orders set branch_id = (select id from public.branches where code = 'MAIN') where branch_id is null;
update public.cafe_tables set branch_id = (select id from public.branches where code = 'MAIN') where branch_id is null;
insert into public.warehouse_stocks (warehouse_id, ingredient_id, quantity)
select (select id from public.warehouses where code = 'MAIN-WH'), id, stock_quantity from public.ingredients
on conflict (warehouse_id, ingredient_id) do nothing;
update public.inventory_movements set warehouse_id = (select id from public.warehouses where code = 'MAIN-WH') where warehouse_id is null;

create index if not exists warehouses_branch_idx on public.warehouses(branch_id);
create index if not exists warehouse_stocks_ingredient_idx on public.warehouse_stocks(ingredient_id);
create index if not exists transfers_source_idx on public.stock_transfers(source_warehouse_id, created_at desc);
create index if not exists orders_branch_idx on public.orders(branch_id, created_at desc);
create trigger branches_updated before update on public.branches for each row execute function public.set_updated_at();
create trigger warehouses_updated before update on public.warehouses for each row execute function public.set_updated_at();

create or replace function public.set_order_branch() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.branch_id is null then
    select branch_id into new.branch_id from public.profiles where id = new.cashier_id;
    if new.branch_id is null then select id into new.branch_id from public.branches where code = 'MAIN'; end if;
  end if;
  return new;
end; $$;
drop trigger if exists orders_branch_before_insert on public.orders;
create trigger orders_branch_before_insert before insert on public.orders for each row execute function public.set_order_branch();

alter table public.branches enable row level security;
alter table public.warehouses enable row level security;
alter table public.warehouse_stocks enable row level security;
alter table public.stock_transfers enable row level security;
alter table public.stock_transfer_items enable row level security;
create policy "staff read branches" on public.branches for select to authenticated using (public.is_staff());
create policy "managers manage branches" on public.branches for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "staff read warehouses" on public.warehouses for select to authenticated using (public.is_staff());
create policy "managers manage warehouses" on public.warehouses for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "staff read warehouse stock" on public.warehouse_stocks for select to authenticated using (public.is_staff());
create policy "managers manage warehouse stock" on public.warehouse_stocks for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "managers manage stock transfers" on public.stock_transfers for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "managers manage transfer items" on public.stock_transfer_items for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());

create or replace function public.adjust_warehouse_stock(p_warehouse_id uuid, p_ingredient_id uuid, p_quantity numeric, p_note text default null)
returns public.warehouse_stocks language plpgsql security definer set search_path = public as $$
declare v_stock public.warehouse_stocks%rowtype;
begin
  if not public.can_manage_catalog() then raise exception 'Manager permission required'; end if;
  if p_quantity = 0 then raise exception 'Quantity must not be zero'; end if;
  insert into public.warehouse_stocks(warehouse_id, ingredient_id, quantity) values(p_warehouse_id, p_ingredient_id, 0) on conflict do nothing;
  select * into v_stock from public.warehouse_stocks where warehouse_id = p_warehouse_id and ingredient_id = p_ingredient_id for update;
  if v_stock.quantity + p_quantity < 0 then raise exception 'Insufficient stock in this warehouse'; end if;
  update public.warehouse_stocks set quantity = quantity + p_quantity, updated_at = now() where warehouse_id = p_warehouse_id and ingredient_id = p_ingredient_id returning * into v_stock;
  insert into public.inventory_movements(ingredient_id, warehouse_id, movement_type, quantity, note, created_by)
  values(p_ingredient_id, p_warehouse_id, case when p_quantity > 0 then 'stock_in' else 'adjustment' end, p_quantity, nullif(trim(p_note), ''), auth.uid());
  return v_stock;
end; $$;

create or replace function public.manage_employee(p_profile_id uuid, p_role public.app_role, p_is_active boolean, p_branch_id uuid)
returns public.profiles language plpgsql security definer set search_path = public as $$
declare v_actor public.profiles%rowtype; v_before public.profiles%rowtype; v_after public.profiles%rowtype;
begin
  select * into v_actor from public.profiles where id = auth.uid() and is_active;
  if v_actor.role <> 'super_admin' then raise exception 'Only Super Admin may manage employees'; end if;
  select * into v_before from public.profiles where id = p_profile_id for update;
  if v_before.id is null then raise exception 'Employee not found'; end if;
  if p_profile_id = auth.uid() and not p_is_active then raise exception 'You cannot deactivate your own account'; end if;
  if not exists (select 1 from public.branches where id = p_branch_id and is_active) then raise exception 'Choose an active branch'; end if;
  update public.profiles set role = p_role, is_active = p_is_active, branch_id = p_branch_id where id = p_profile_id returning * into v_after;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, before_data, after_data) values(auth.uid(), 'employee.updated', 'profile', p_profile_id, to_jsonb(v_before), to_jsonb(v_after));
  return v_after;
end; $$;

grant select on public.branches, public.warehouses, public.warehouse_stocks, public.stock_transfers, public.stock_transfer_items to authenticated;
grant execute on function public.adjust_warehouse_stock(uuid, uuid, numeric, text) to authenticated;
grant execute on function public.manage_employee(uuid, public.app_role, boolean, uuid) to authenticated;
