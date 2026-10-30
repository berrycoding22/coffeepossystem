-- CoffeeFlow POS · Phase 2 foundation. Run this entire file in Supabase SQL Editor.
create extension if not exists "pgcrypto";

create type public.app_role as enum ('super_admin', 'manager', 'cashier', 'barista');
create type public.order_status as enum ('pending', 'preparing', 'ready', 'completed', 'cancelled');
create type public.order_type as enum ('dine_in', 'takeaway', 'delivery');
create type public.payment_status as enum ('pending', 'paid', 'failed', 'refunded', 'partially_refunded');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  role public.app_role not null default 'cashier',
  avatar_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(), name text not null unique, khmer_name text,
  description text, image_url text, sort_order integer not null default 0, is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.products (
  id uuid primary key default gen_random_uuid(), category_id uuid references public.categories(id) on delete set null,
  sku text unique, name text not null, khmer_name text, description text, image_url text,
  base_price numeric(12,2) not null check (base_price >= 0), cost_price numeric(12,2) not null default 0 check (cost_price >= 0),
  is_active boolean not null default true, is_available boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.product_variants (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete cascade,
  name text not null, price_adjustment numeric(12,2) not null default 0, is_default boolean not null default false, is_active boolean not null default true,
  unique(product_id, name)
);
create table public.product_modifiers (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete cascade,
  name text not null, modifier_group text not null, price_adjustment numeric(12,2) not null default 0, is_active boolean not null default true
);
create table public.ingredients (
  id uuid primary key default gen_random_uuid(), name text not null unique, unit text not null, stock_quantity numeric(14,3) not null default 0,
  reorder_level numeric(14,3) not null default 0, cost_per_unit numeric(12,4) not null default 0, is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.recipes (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id) on delete restrict, quantity numeric(14,3) not null check (quantity > 0),
  unique(product_id, ingredient_id)
);
create table public.customers (id uuid primary key default gen_random_uuid(), full_name text not null, phone text unique, email text, created_at timestamptz not null default now());
create table public.cafe_tables (id uuid primary key default gen_random_uuid(), table_number text not null unique, seats integer not null default 2 check(seats > 0), status text not null default 'available' check (status in ('available','occupied','reserved','cleaning')));
create table public.orders (
  id uuid primary key default gen_random_uuid(), order_number text not null unique, customer_id uuid references public.customers(id) on delete set null,
  table_id uuid references public.cafe_tables(id) on delete set null, cashier_id uuid references public.profiles(id) on delete set null,
  status public.order_status not null default 'pending', order_type public.order_type not null default 'takeaway', notes text,
  subtotal numeric(12,2) not null default 0, discount_amount numeric(12,2) not null default 0, tax_amount numeric(12,2) not null default 0, total_amount numeric(12,2) not null default 0,
  created_at timestamptz not null default now(), completed_at timestamptz
);
create table public.order_items (
  id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null, product_name text not null, quantity integer not null check(quantity > 0),
  unit_price numeric(12,2) not null check(unit_price >= 0), total_price numeric(12,2) not null check(total_price >= 0), customization jsonb not null default '{}'::jsonb, notes text
);
create table public.payments (
  id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete restrict,
  method text not null check(method in ('cash_usd','cash_khr','khqr','bank_transfer','mixed')), currency text not null check(currency in ('USD','KHR')),
  amount numeric(12,2) not null check(amount >= 0), exchange_rate numeric(12,2), status public.payment_status not null default 'pending', provider_reference text unique, recorded_by uuid references public.profiles(id), created_at timestamptz not null default now()
);
create table public.expenses (id uuid primary key default gen_random_uuid(), category text not null, amount numeric(12,2) not null check(amount > 0), currency text not null default 'USD', expense_date date not null default current_date, note text, receipt_url text, created_by uuid references public.profiles(id), created_at timestamptz not null default now());
create table public.inventory_movements (id uuid primary key default gen_random_uuid(), ingredient_id uuid not null references public.ingredients(id), movement_type text not null check(movement_type in ('stock_in','stock_out','adjustment','waste','sale_deduction','refund_restore')), quantity numeric(14,3) not null, reference_type text, reference_id uuid, note text, created_by uuid references public.profiles(id), created_at timestamptz not null default now());
create table public.audit_logs (id bigint generated always as identity primary key, actor_id uuid references public.profiles(id), action text not null, entity_type text not null, entity_id uuid, before_data jsonb, after_data jsonb, created_at timestamptz not null default now());

create index products_category_idx on public.products(category_id); create index orders_created_idx on public.orders(created_at desc); create index orders_status_idx on public.orders(status); create index order_items_order_idx on public.order_items(order_id); create index inventory_ingredient_idx on public.inventory_movements(ingredient_id);

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
create trigger profiles_updated before update on public.profiles for each row execute function public.set_updated_at();
create trigger categories_updated before update on public.categories for each row execute function public.set_updated_at();
create trigger products_updated before update on public.products for each row execute function public.set_updated_at();
create trigger ingredients_updated before update on public.ingredients for each row execute function public.set_updated_at();

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$ begin insert into public.profiles (id, full_name) values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1))); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
insert into public.profiles (id, full_name) select id, coalesce(raw_user_meta_data ->> 'full_name', split_part(email, '@', 1)) from auth.users on conflict (id) do nothing;

create or replace function public.is_staff() returns boolean language sql stable security definer set search_path = public as $$ select exists (select 1 from public.profiles where id = auth.uid() and is_active); $$;
create or replace function public.can_manage_catalog() returns boolean language sql stable security definer set search_path = public as $$ select exists (select 1 from public.profiles where id = auth.uid() and is_active and role in ('super_admin','manager')); $$;

alter table public.profiles enable row level security; alter table public.categories enable row level security; alter table public.products enable row level security; alter table public.product_variants enable row level security; alter table public.product_modifiers enable row level security; alter table public.ingredients enable row level security; alter table public.recipes enable row level security; alter table public.customers enable row level security; alter table public.cafe_tables enable row level security; alter table public.orders enable row level security; alter table public.order_items enable row level security; alter table public.payments enable row level security; alter table public.expenses enable row level security; alter table public.inventory_movements enable row level security; alter table public.audit_logs enable row level security;
create policy "profiles self read" on public.profiles for select to authenticated using (id = auth.uid() or public.can_manage_catalog()); create policy "profiles self update" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid() and role = (select role from public.profiles where id = auth.uid()));
create policy "staff read categories" on public.categories for select to authenticated using (public.is_staff()); create policy "managers manage categories" on public.categories for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "staff read products" on public.products for select to authenticated using (public.is_staff()); create policy "managers manage products" on public.products for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "staff read variants" on public.product_variants for select to authenticated using (public.is_staff()); create policy "managers manage variants" on public.product_variants for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "staff read modifiers" on public.product_modifiers for select to authenticated using (public.is_staff()); create policy "managers manage modifiers" on public.product_modifiers for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "staff read ingredients" on public.ingredients for select to authenticated using (public.is_staff()); create policy "managers manage ingredients" on public.ingredients for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "staff read recipes" on public.recipes for select to authenticated using (public.is_staff()); create policy "managers manage recipes" on public.recipes for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create policy "staff manage customers" on public.customers for all to authenticated using (public.is_staff()) with check (public.is_staff()); create policy "staff manage tables" on public.cafe_tables for all to authenticated using (public.is_staff()) with check (public.is_staff()); create policy "staff manage orders" on public.orders for all to authenticated using (public.is_staff()) with check (public.is_staff()); create policy "staff manage order items" on public.order_items for all to authenticated using (public.is_staff()) with check (public.is_staff()); create policy "staff manage payments" on public.payments for all to authenticated using (public.is_staff()) with check (public.is_staff()); create policy "managers manage expenses" on public.expenses for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog()); create policy "managers manage movements" on public.inventory_movements for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog()); create policy "managers read audit logs" on public.audit_logs for select to authenticated using (public.can_manage_catalog());

-- Promote your first development user after running this file (replace the email):
-- update public.profiles set role = 'super_admin' where id = (select id from auth.users where email = 'admin@example.com');
