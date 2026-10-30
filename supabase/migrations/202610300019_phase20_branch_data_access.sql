-- CoffeeFlow POS · Phase 20: Branch-aware operational data access.
-- Run after 202610300018_phase19_sales_orders_delivery.sql.

create or replace function public.can_access_branch(p_branch_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_active
      and (role = 'super_admin' or branch_id = p_branch_id)
  );
$$;

drop policy if exists "staff read orders" on public.orders;
drop policy if exists "staff read order items" on public.order_items;
drop policy if exists "staff read payments" on public.payments;
create policy "branch staff read orders" on public.orders for select to authenticated using (public.can_access_branch(branch_id));
create policy "branch staff read order items" on public.order_items for select to authenticated using (exists(select 1 from public.orders o where o.id = order_id and public.can_access_branch(o.branch_id)));
create policy "branch staff read payments" on public.payments for select to authenticated using (exists(select 1 from public.orders o where o.id = order_id and public.can_access_branch(o.branch_id)));

drop policy if exists "staff manage tables" on public.cafe_tables;
create policy "branch staff manage tables" on public.cafe_tables for all to authenticated using (public.can_access_branch(branch_id)) with check (public.can_access_branch(branch_id));

drop policy if exists "staff read sales orders" on public.sales_orders;
drop policy if exists "staff read sales order items" on public.sales_order_items;
create policy "branch staff read sales orders" on public.sales_orders for select to authenticated using (public.can_access_branch(branch_id));
create policy "branch staff read sales order items" on public.sales_order_items for select to authenticated using (exists(select 1 from public.sales_orders so where so.id = sales_order_id and public.can_access_branch(so.branch_id)));

create or replace function public.assign_profile_branch() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.branch_id is null then select id into new.branch_id from public.branches where code = 'MAIN'; end if;
  return new;
end; $$;
drop trigger if exists profiles_assign_branch on public.profiles;
create trigger profiles_assign_branch before insert on public.profiles for each row execute function public.assign_profile_branch();

grant execute on function public.can_access_branch(uuid) to authenticated;
