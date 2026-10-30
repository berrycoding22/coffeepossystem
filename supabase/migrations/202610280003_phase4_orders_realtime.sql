-- CoffeeFlow POS · Phase 4 orders, kitchen and realtime.
alter table public.orders replica identity full;
alter table public.cafe_tables replica identity full;
do $$ begin alter publication supabase_realtime add table public.orders; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.cafe_tables; exception when duplicate_object then null; end $$;

create or replace function public.set_order_status(p_order_id uuid, p_status public.order_status)
returns public.orders language plpgsql security definer set search_path = public as $$
declare v_profile public.profiles%rowtype; v_order public.orders%rowtype;
begin
  select * into v_profile from public.profiles where id = auth.uid() and is_active;
  if v_profile.id is null then raise exception 'An active staff account is required'; end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.id is null then raise exception 'Order not found'; end if;
  if v_profile.role = 'barista' and p_status not in ('preparing','ready') then raise exception 'Baristas may only set preparing or ready'; end if;
  if v_profile.role = 'cashier' and p_status not in ('completed','cancelled') then raise exception 'Cashiers may only complete or cancel orders'; end if;
  if p_status = 'cancelled' and v_profile.role not in ('super_admin','manager','cashier') then raise exception 'Not permitted to cancel'; end if;
  if v_order.status in ('completed','cancelled') and p_status <> v_order.status then raise exception 'Closed orders cannot be changed'; end if;
  update public.orders set status = p_status, completed_at = case when p_status = 'completed' then now() else completed_at end where id = p_order_id returning * into v_order;
  return v_order;
end; $$;
grant execute on function public.set_order_status(uuid, public.order_status) to authenticated;
