-- CoffeeFlow POS · Phase 17: Full sales returns and refund reconciliation.
-- Run after 202610300015_phase16_inventory_waste.sql.

create or replace function public.refund_completed_order(p_order_id uuid, p_reason text default null) returns void language plpgsql security definer set search_path = public as $$
declare v_profile public.profiles%rowtype; v_order public.orders%rowtype; v record; v_credit_amount numeric(12,2) := 0;
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
  select coalesce(sum(amount), 0) into v_credit_amount from public.payments where order_id = p_order_id and method = 'credit';
  if v_credit_amount > 0 and v_order.customer_id is not null then update public.customers set credit_balance = greatest(0, credit_balance - v_order.total_amount) where id = v_order.customer_id; end if;
  update public.payments set status = 'refunded' where order_id = p_order_id and status in ('paid', 'pending');
  insert into public.refunds(order_id, amount, reason, processed_by) values(p_order_id, v_order.total_amount, nullif(trim(p_reason), ''), auth.uid());
  update public.orders set status = 'cancelled' where id = p_order_id;
end; $$;
grant execute on function public.refund_completed_order(uuid, text) to authenticated;
