# CoffeeFlow POS

CoffeeFlow is a bilingual-ready, dual-currency coffee shop POS built with Next.js App Router and Supabase.

## Phase 1 architecture

- **App shell:** Next.js 15, TypeScript, App Router, Tailwind CSS, responsive dashboard layout.
- **Authentication:** Supabase Auth client/server helpers and middleware protect `/dashboard` on the server edge.
- **Authorization boundary:** roles are typed centrally in `src/lib/auth/roles.ts`; database RLS and feature permissions are introduced with the Phase 2 schema.
- **Data layer:** Supabase clients are isolated in `src/lib/supabase`. Browser code only uses the anonymous key; never add a service-role key to `NEXT_PUBLIC_*`.
- **Modules:** dashboard routes establish the POS, order, kitchen, inventory, employee, expense, report, and settings information architecture.

## Run in VS Code

1. Open this folder in VS Code and install Node.js 20.9+.
2. Copy `.env.example` to `.env.local` and enter your Supabase project URL and anonymous key. Keep `SUPABASE_SERVICE_ROLE_KEY` server-only.
3. Run `npm install`.
4. Run `npm run dev`, then open `http://localhost:3000`.
5. In Supabase Authentication, create a development email/password user. The user can sign in at `/login`; the middleware then takes them to `/dashboard`.

## Validation

Run `npm run typecheck` and `npm run build` before deployment. Configure Supabase URL/key in your hosting provider's environment settings.

## Database setup (Phase 2)

1. In Supabase, open **SQL Editor** → **New query**.
2. Paste and run `supabase/migrations/202610280001_phase2_foundation.sql`.
3. Promote your own login to `super_admin` by replacing the email in the final commented statement and running it.
4. Optionally run `supabase/seed.sql` to create the development menu data.

The migration creates the core database foundation, indexes, Auth profile trigger, server-enforced RLS, and catalog/order/payment/inventory tables. Once promoted to `super_admin`, use **Categories** and **Products** in the dashboard to perform catalog CRUD. Checkout and inventory transaction functions remain Phase 3 work.

## POS checkout (Phase 3)

Run `supabase/migrations/202610280002_phase3_pos_checkout.sql` in Supabase SQL Editor after Phase 2. It adds the transactional `checkout_pos_order` function. The POS only sends product IDs and quantities; prices, totals, payment state, and order numbers are computed by PostgreSQL. Cash payments are recorded as paid. KHQR and bank-transfer orders remain pending until a provider integration verifies them.

## Orders and kitchen (Phase 4)

Run `supabase/migrations/202610280003_phase4_orders_realtime.sql` in Supabase SQL Editor after Phase 3. It enables Realtime for orders and tables and adds a role-checked order-status function. The **Orders**, **Kitchen Display**, and **Tables** dashboard pages then use live database records.

## Inventory (Phase 5)

Run `supabase/migrations/202610290004_phase5_inventory.sql` in Supabase SQL Editor after Phase 4. It adds suppliers, purchase/refund records, recipe-based inventory movements, stock receiving, and transactional deduction when an order is completed. Add ingredients in **Inventory**, then associate them with products in the `recipes` table before using automatic deduction.

## Remaining migrations

Run these in order after Phase 5:

1. `202610290005_phase6_admin_reports.sql` — employee administration, expenses, reports.
2. `202610290006_phase7_settings.sql` — protected store settings and configurable exchange rate.
3. `202610290007_phase8_security_hardening.sql` — blocks direct client writes to critical financial and inventory tables.

## Production deployment

1. Run `npm.cmd install` and `npm.cmd run build` locally.
2. Deploy the repository to a Next.js-compatible host such as Vercel.
3. Configure `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` in the host environment. Do not expose `SUPABASE_SERVICE_ROLE_KEY` to the browser.
4. In Supabase Authentication URL Configuration, add the production site URL and password-reset redirect URL.
5. Run [verification.sql](supabase/verification.sql) in Supabase SQL Editor and perform a real sale → kitchen status → complete-order stock-deduction test.

KHQR remains intentionally pending until an approved payment-provider webhook verifies the payment; this project does not simulate that confirmation.
