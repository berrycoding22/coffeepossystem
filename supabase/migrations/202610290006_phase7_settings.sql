-- CoffeeFlow POS · Phase 7 store configuration.
create table if not exists public.store_settings (
  id boolean primary key default true check (id), shop_name text not null default 'CoffeeFlow POS', shop_address text,
  phone text, tax_rate numeric(5,2) not null default 0 check(tax_rate >= 0), exchange_rate numeric(12,2) not null default 4100 check(exchange_rate > 0),
  receipt_footer text not null default 'Thank you! Please come again!', default_order_type public.order_type not null default 'takeaway', language text not null default 'en' check(language in ('en','km')),
  updated_at timestamptz not null default now(), updated_by uuid references public.profiles(id)
);
insert into public.store_settings(id) values(true) on conflict (id) do nothing;
alter table public.store_settings enable row level security;
create policy "staff read settings" on public.store_settings for select to authenticated using (public.is_staff());
create policy "managers update settings" on public.store_settings for update to authenticated using (public.can_manage_catalog()) with check (public.can_manage_catalog());
create or replace function public.touch_store_settings() returns trigger language plpgsql as $$ begin new.updated_at = now(); new.updated_by = auth.uid(); return new; end; $$;
create trigger store_settings_updated before update on public.store_settings for each row execute function public.touch_store_settings();
