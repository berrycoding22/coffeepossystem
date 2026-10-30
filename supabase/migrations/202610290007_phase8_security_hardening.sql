-- CoffeeFlow POS · Phase 8 security hardening. Run after all previous migrations.
-- Checkout, order status changes, refunds, and stock adjustments must now use database functions.
drop policy if exists "staff manage orders" on public.orders;
drop policy if exists "staff manage order items" on public.order_items;
drop policy if exists "staff manage payments" on public.payments;
drop policy if exists "managers manage movements" on public.inventory_movements;
create policy "staff read orders" on public.orders for select to authenticated using (public.is_staff());
create policy "staff read order items" on public.order_items for select to authenticated using (public.is_staff());
create policy "staff read payments" on public.payments for select to authenticated using (public.is_staff());
create policy "managers read inventory movements" on public.inventory_movements for select to authenticated using (public.can_manage_catalog());
revoke insert, update, delete on public.orders, public.order_items, public.payments, public.inventory_movements from authenticated;
grant select on public.orders, public.order_items, public.payments to authenticated;
grant execute on function public.checkout_pos_order(jsonb, public.order_type, text, numeric, text, text, numeric, numeric, uuid) to authenticated;
grant execute on function public.set_order_status(uuid, public.order_status), public.receive_inventory(uuid, numeric, text), public.refund_completed_order(uuid, text), public.manage_employee(uuid, public.app_role, boolean) to authenticated;
