-- CoffeeFlow POS · Phase 13: Warehouse-to-warehouse stock transfers.
-- Run after 202610300011_phase12_pos_customer_credit.sql.

create sequence if not exists public.stock_transfer_number_sequence;
create or replace function public.complete_stock_transfer(p_source_warehouse_id uuid, p_destination_warehouse_id uuid, p_items jsonb, p_note text default null)
returns public.stock_transfers language plpgsql security definer set search_path = public as $$
declare v_transfer public.stock_transfers%rowtype; v_item jsonb; v_ingredient_id uuid; v_quantity numeric(14,3); v_stock public.warehouse_stocks%rowtype;
begin
  if not public.can_manage_catalog() then raise exception 'Manager permission required'; end if;
  if p_source_warehouse_id = p_destination_warehouse_id then raise exception 'Choose two different warehouses'; end if;
  if not exists(select 1 from public.warehouses where id = p_source_warehouse_id and is_active) or not exists(select 1 from public.warehouses where id = p_destination_warehouse_id and is_active) then raise exception 'Warehouse not found'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Add at least one item'; end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_ingredient_id := (v_item ->> 'ingredient_id')::uuid; v_quantity := (v_item ->> 'quantity')::numeric;
    if v_quantity is null or v_quantity <= 0 then raise exception 'Invalid transfer quantity'; end if;
    select * into v_stock from public.warehouse_stocks where warehouse_id = p_source_warehouse_id and ingredient_id = v_ingredient_id for update;
    if v_stock.warehouse_id is null or v_stock.quantity < v_quantity then raise exception 'Insufficient source stock'; end if;
  end loop;
  insert into public.stock_transfers(transfer_number, source_warehouse_id, destination_warehouse_id, status, note, created_by, completed_at)
  values('TRF-' || to_char(current_date, 'YYYYMMDD') || '-' || lpad(nextval('public.stock_transfer_number_sequence')::text, 5, '0'), p_source_warehouse_id, p_destination_warehouse_id, 'completed', nullif(trim(p_note), ''), auth.uid(), now()) returning * into v_transfer;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_ingredient_id := (v_item ->> 'ingredient_id')::uuid; v_quantity := (v_item ->> 'quantity')::numeric;
    insert into public.stock_transfer_items(transfer_id, ingredient_id, quantity) values(v_transfer.id, v_ingredient_id, v_quantity);
    update public.warehouse_stocks set quantity = quantity - v_quantity, updated_at = now() where warehouse_id = p_source_warehouse_id and ingredient_id = v_ingredient_id;
    insert into public.warehouse_stocks(warehouse_id, ingredient_id, quantity) values(p_destination_warehouse_id, v_ingredient_id, v_quantity)
    on conflict (warehouse_id, ingredient_id) do update set quantity = public.warehouse_stocks.quantity + excluded.quantity, updated_at = now();
    insert into public.inventory_movements(ingredient_id, warehouse_id, movement_type, quantity, reference_type, reference_id, note, created_by) values(v_ingredient_id, p_source_warehouse_id, 'stock_out', -v_quantity, 'stock_transfer_out', v_transfer.id, 'Warehouse transfer out', auth.uid());
    insert into public.inventory_movements(ingredient_id, warehouse_id, movement_type, quantity, reference_type, reference_id, note, created_by) values(v_ingredient_id, p_destination_warehouse_id, 'stock_in', v_quantity, 'stock_transfer_in', v_transfer.id, 'Warehouse transfer in', auth.uid());
  end loop;
  return v_transfer;
end; $$;
grant execute on function public.complete_stock_transfer(uuid, uuid, jsonb, text) to authenticated;
