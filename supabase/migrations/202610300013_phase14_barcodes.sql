-- CoffeeFlow POS · Phase 14: Scannable product barcode labels.
-- Run after 202610300012_phase13_stock_transfers.sql.

alter table public.products add column if not exists barcode text;
update public.products set barcode = 'CF-' || upper(left(replace(id::text, '-', ''), 10)) where barcode is null;
alter table public.products alter column barcode set not null;
create unique index if not exists products_barcode_unique on public.products(barcode);
create or replace function public.assign_product_barcode() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.barcode is null or trim(new.barcode) = '' then new.barcode := 'CF-' || upper(left(replace(gen_random_uuid()::text, '-', ''), 10)); end if;
  return new;
end; $$;
drop trigger if exists products_assign_barcode on public.products;
create trigger products_assign_barcode before insert on public.products for each row execute function public.assign_product_barcode();
