-- CoffeeFlow POS · Phase 3 checkout. Run after 202610280001_phase2_foundation.sql.
alter table public.orders add column if not exists checkout_key uuid unique;
create sequence if not exists public.order_number_sequence;

create or replace function public.checkout_pos_order(
  p_items jsonb,
  p_order_type public.order_type default 'takeaway',
  p_notes text default null,
  p_discount numeric default 0,
  p_payment_method text default 'cash_usd',
  p_currency text default 'USD',
  p_amount_received numeric default null,
  p_exchange_rate numeric default 4100,
  p_checkout_key uuid default gen_random_uuid()
) returns table(order_id uuid, order_number text, total_amount numeric, payment_status public.payment_status)
language plpgsql security definer set search_path = public as $$
declare
  v_profile public.profiles%rowtype; v_order_id uuid; v_order_number text; v_subtotal numeric(12,2) := 0;
  v_discount numeric(12,2) := greatest(coalesce(p_discount, 0), 0); v_total numeric(12,2); v_item jsonb;
  v_product public.products%rowtype; v_quantity integer; v_status public.payment_status; v_payment_amount numeric(12,2);
begin
  select * into v_profile from public.profiles where id = auth.uid() and is_active;
  if v_profile.id is null then raise exception 'A signed-in active staff account is required'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Cart must contain at least one item'; end if;
  if p_payment_method not in ('cash_usd','cash_khr','khqr','bank_transfer','mixed') then raise exception 'Invalid payment method'; end if;
  if p_currency not in ('USD','KHR') then raise exception 'Invalid currency'; end if;
  select o.id, o.order_number, o.total_amount, (select p.status from public.payments p where p.order_id = o.id order by p.created_at limit 1) into v_order_id, v_order_number, v_total, v_status from public.orders o where o.checkout_key = p_checkout_key;
  if v_order_id is not null then return query select v_order_id, v_order_number, v_total, v_status; return; end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_quantity := (v_item ->> 'quantity')::integer;
    if v_quantity is null or v_quantity < 1 then raise exception 'Invalid item quantity'; end if;
    select * into v_product from public.products where id = (v_item ->> 'product_id')::uuid and is_active and is_available for share;
    if v_product.id is null then raise exception 'A selected product is unavailable'; end if;
    v_subtotal := v_subtotal + (v_product.base_price * v_quantity);
  end loop;
  v_discount := least(v_discount, v_subtotal); v_total := v_subtotal - v_discount;
  v_order_number := 'ORD-' || to_char(current_date, 'YYYYMMDD') || '-' || lpad(nextval('public.order_number_sequence')::text, 5, '0');
  insert into public.orders (order_number, cashier_id, status, order_type, notes, subtotal, discount_amount, total_amount, checkout_key)
  values (v_order_number, auth.uid(), 'pending', p_order_type, nullif(trim(p_notes), ''), v_subtotal, v_discount, v_total, p_checkout_key) returning id into v_order_id;
  for v_item in select value from jsonb_array_elements(p_items) loop
    select * into v_product from public.products where id = (v_item ->> 'product_id')::uuid;
    v_quantity := (v_item ->> 'quantity')::integer;
    insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, total_price, customization, notes)
    values (v_order_id, v_product.id, v_product.name, v_quantity, v_product.base_price, v_product.base_price * v_quantity, coalesce(v_item -> 'customization', '{}'::jsonb), nullif(v_item ->> 'notes', ''));
  end loop;
  if p_exchange_rate <= 0 then raise exception 'Invalid exchange rate'; end if;
  v_payment_amount := case when p_currency = 'KHR' then round(v_total * p_exchange_rate, 0) else v_total end;
  v_status := case when p_payment_method in ('cash_usd', 'cash_khr') then 'paid'::public.payment_status else 'pending'::public.payment_status end;
  if p_payment_method in ('cash_usd','cash_khr') and coalesce(p_amount_received, 0) < v_payment_amount then raise exception 'Cash received is less than the order total'; end if;
  insert into public.payments (order_id, method, currency, amount, status, recorded_by)
  values (v_order_id, p_payment_method, p_currency, v_payment_amount, v_status, auth.uid());
  return query select v_order_id, v_order_number, v_total, v_status;
end; $$;

grant execute on function public.checkout_pos_order(jsonb, public.order_type, text, numeric, text, text, numeric, numeric, uuid) to authenticated;
