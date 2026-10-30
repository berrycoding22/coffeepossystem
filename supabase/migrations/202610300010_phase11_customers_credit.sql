-- CoffeeFlow POS · Phase 11: Customers and credit-payment ledger.
-- Run after 202610300009_phase10_purchase_orders.sql.

alter table public.customers add column if not exists code text;
alter table public.customers add column if not exists address text;
alter table public.customers add column if not exists credit_limit numeric(12,2) not null default 0 check(credit_limit >= 0);
alter table public.customers add column if not exists credit_balance numeric(12,2) not null default 0 check(credit_balance >= 0);
alter table public.customers add column if not exists is_active boolean not null default true;
alter table public.customers add column if not exists updated_at timestamptz not null default now();
create unique index if not exists customers_code_unique on public.customers(code) where code is not null;
create trigger customers_updated before update on public.customers for each row execute function public.set_updated_at();

create table if not exists public.customer_payments (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete restrict,
  amount numeric(12,2) not null check(amount > 0),
  currency text not null default 'USD' check(currency in ('USD', 'KHR')),
  exchange_rate numeric(12,2),
  method text not null default 'cash_usd' check(method in ('cash_usd', 'cash_khr', 'khqr', 'bank_transfer')),
  note text,
  received_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists customer_payments_customer_idx on public.customer_payments(customer_id, created_at desc);
alter table public.customer_payments enable row level security;
create policy "managers manage customer payments" on public.customer_payments for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());

create or replace function public.record_customer_payment(p_customer_id uuid, p_amount numeric, p_currency text default 'USD', p_method text default 'cash_usd', p_note text default null)
returns public.customers language plpgsql security definer set search_path = public as $$
declare v_customer public.customers%rowtype;
begin
  if not public.can_manage_catalog() then raise exception 'Manager permission required'; end if;
  if p_amount <= 0 then raise exception 'Payment amount must be positive'; end if;
  if p_currency not in ('USD', 'KHR') or p_method not in ('cash_usd', 'cash_khr', 'khqr', 'bank_transfer') then raise exception 'Invalid payment method'; end if;
  select * into v_customer from public.customers where id = p_customer_id and is_active for update;
  if v_customer.id is null then raise exception 'Customer not found'; end if;
  if p_currency = 'USD' and p_amount > v_customer.credit_balance then raise exception 'Payment exceeds customer credit balance'; end if;
  insert into public.customer_payments(customer_id, amount, currency, method, note, received_by) values(p_customer_id, p_amount, p_currency, p_method, nullif(trim(p_note), ''), auth.uid());
  if p_currency = 'USD' then update public.customers set credit_balance = credit_balance - p_amount where id = p_customer_id returning * into v_customer; end if;
  return v_customer;
end; $$;
grant select on public.customer_payments to authenticated;
grant execute on function public.record_customer_payment(uuid, numeric, text, text, text) to authenticated;
