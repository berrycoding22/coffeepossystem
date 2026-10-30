-- CoffeeFlow POS · Phase 6 employee administration, expenses and reporting.
create index if not exists expenses_date_idx on public.expenses(expense_date desc);
create or replace function public.manage_employee(p_profile_id uuid, p_role public.app_role, p_is_active boolean)
returns public.profiles language plpgsql security definer set search_path = public as $$
declare v_actor public.profiles%rowtype; v_before public.profiles%rowtype; v_after public.profiles%rowtype;
begin
  select * into v_actor from public.profiles where id = auth.uid() and is_active;
  if v_actor.role <> 'super_admin' then raise exception 'Only Super Admin may manage employees'; end if;
  select * into v_before from public.profiles where id = p_profile_id for update;
  if v_before.id is null then raise exception 'Employee not found'; end if;
  if p_profile_id = auth.uid() and not p_is_active then raise exception 'You cannot deactivate your own account'; end if;
  update public.profiles set role = p_role, is_active = p_is_active where id = p_profile_id returning * into v_after;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, before_data, after_data) values(auth.uid(), 'employee.updated', 'profile', p_profile_id, to_jsonb(v_before), to_jsonb(v_after));
  return v_after;
end; $$;
grant execute on function public.manage_employee(uuid, public.app_role, boolean) to authenticated;
