-- CoffeeFlow POS · Phase 15: Supplier payable bills and payments.
-- Run after 202610300013_phase14_barcodes.sql.

alter table public.purchases add column if not exists amount_paid numeric(12,2) not null default 0 check(amount_paid >= 0);
alter table public.purchases add column if not exists payment_status text not null default 'unpaid' check(payment_status in ('unpaid', 'partial', 'paid'));
create table if not exists public.supplier_payments (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete restrict,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  amount numeric(12,2) not null check(amount > 0),
  currency text not null default 'USD' check(currency in ('USD', 'KHR')),
  method text not null default 'cash_usd' check(method in ('cash_usd', 'cash_khr', 'khqr', 'bank_transfer')),
  note text,
  recorded_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists supplier_payments_purchase_idx on public.supplier_payments(purchase_id, created_at desc);
alter table public.supplier_payments enable row level security;
create policy "managers manage supplier payments" on public.supplier_payments for all to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());

create or replace function public.record_supplier_payment(p_purchase_id uuid, p_amount numeric, p_method text default 'cash_usd', p_note text default null)
returns public.purchases language plpgsql security definer set search_path = public as $$
declare v_purchase public.purchases%rowtype;
begin
  if not public.can_manage_catalog() then raise exception 'Manager permission required'; end if;
  if p_amount <= 0 then raise exception 'Payment amount must be positive'; end if;
  if p_method not in ('cash_usd', 'cash_khr', 'khqr', 'bank_transfer') then raise exception 'Invalid payment method'; end if;
  select * into v_purchase from public.purchases where id = p_purchase_id for update;
  if v_purchase.id is null then raise exception 'Purchase order not found'; end if;
  if v_purchase.status <> 'received' then raise exception 'Receive stock before paying this bill'; end if;
  if v_purchase.amount_paid + p_amount > v_purchase.total_amount then raise exception 'Payment exceeds the outstanding bill amount'; end if;
  insert into public.supplier_payments(purchase_id, supplier_id, amount, method, note, recorded_by) values(v_purchase.id, v_purchase.supplier_id, p_amount, p_method, nullif(trim(p_note), ''), auth.uid());
  update public.purchases set amount_paid = amount_paid + p_amount, payment_status = case when amount_paid + p_amount >= total_amount then 'paid' else 'partial' end where id = v_purchase.id returning * into v_purchase;
  return v_purchase;
end; $$;
grant select on public.supplier_payments to authenticated;
grant execute on function public.record_supplier_payment(uuid, numeric, text, text) to authenticated;
