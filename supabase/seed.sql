-- Phase 1 intentionally contains no production/demo database records.
-- Phase 2 will provide clearly-marked development sample data.
-- DEVELOPMENT DEMO DATA ONLY. Run after 202610280001_phase2_foundation.sql.
insert into public.categories (name, khmer_name, sort_order) values
  ('Hot Coffee', 'កាហ្វេក្តៅ', 1), ('Iced Coffee', 'កាហ្វេទឹកកក', 2), ('Milk Tea', 'តែទឹកដោះគោ', 3), ('Fruit Tea', 'តែផ្លែឈើ', 4),
  ('Smoothies', 'ស្មូតធី', 5), ('Soft Drinks', 'ភេសជ្ជៈត្រជាក់', 6), ('Bakery', 'នំ', 7), ('Snacks', 'អាហារសម្រន់', 8)
on conflict (name) do nothing;

insert into public.products (category_id, sku, name, khmer_name, base_price, cost_price) values
  ((select id from public.categories where name = 'Hot Coffee'), 'HOT-001', 'Espresso', 'អេសប្រេសូ', 2.00, 0.55),
  ((select id from public.categories where name = 'Hot Coffee'), 'HOT-002', 'Cappuccino', 'កាពូជីណូ', 3.00, 0.90),
  ((select id from public.categories where name = 'Hot Coffee'), 'HOT-003', 'Café Latte', 'កាហ្វេឡាតេ', 3.25, 1.00),
  ((select id from public.categories where name = 'Iced Coffee'), 'ICE-001', 'Iced Latte', 'ឡាតេទឹកកក', 3.50, 1.10),
  ((select id from public.categories where name = 'Iced Coffee'), 'ICE-002', 'Iced Caramel Latte', 'ឡាតេការ៉ាមែលទឹកកក', 4.25, 1.35),
  ((select id from public.categories where name = 'Milk Tea'), 'TEA-001', 'Brown Sugar Milk Tea', 'តែទឹកដោះគោស្ករត្នោត', 3.75, 1.20),
  ((select id from public.categories where name = 'Milk Tea'), 'TEA-002', 'Taro Milk Tea', 'តែទឹកដោះគោត្រាវ', 3.50, 1.15),
  ((select id from public.categories where name = 'Fruit Tea'), 'TEA-003', 'Passion Fruit Tea', 'តែផ្លែស្វាយចន្ទី', 3.25, 0.90),
  ((select id from public.categories where name = 'Smoothies'), 'SMO-001', 'Mango Smoothie', 'ស្មូតធីស្វាយ', 3.75, 1.25),
  ((select id from public.categories where name = 'Soft Drinks'), 'DRK-001', 'Iced Lemon Tea', 'តែក្រូចឆ្មាទឹកកក', 2.50, 0.55),
  ((select id from public.categories where name = 'Bakery'), 'BAK-001', 'Butter Croissant', 'គ្រូសង់ប៊ឺ', 2.20, 0.80),
  ((select id from public.categories where name = 'Bakery'), 'BAK-002', 'Chocolate Muffin', 'នំម៉ាហ្វិនសូកូឡា', 2.50, 0.85)
on conflict (sku) do nothing;
