-- Read-only production verification queries. Run after all migrations.
select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by c.relname;
select proname from pg_proc join pg_namespace on pg_namespace.oid = pg_proc.pronamespace where nspname = 'public' and proname in ('checkout_pos_order','set_order_status','receive_inventory','refund_completed_order','manage_employee');
select 'categories' as entity, count(*) from public.categories union all select 'products', count(*) from public.products union all select 'orders', count(*) from public.orders union all select 'ingredients', count(*) from public.ingredients;
select order_number, status, total_amount, created_at from public.orders order by created_at desc limit 10;
select name, stock_quantity, reorder_level, unit from public.ingredients order by name;
select full_name, role, b.name as assigned_branch from public.profiles p left join public.branches b on b.id = p.branch_id order by full_name;
select order_number, b.name as branch, status, total_amount from public.orders o left join public.branches b on b.id = o.branch_id order by o.created_at desc limit 20;
