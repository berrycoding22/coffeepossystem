import { ReportsDashboard } from "@/components/reports/reports-dashboard";
import { createClient } from "@/lib/supabase/server";

export default async function ReportsPage() {
  const supabase = await createClient(); const from = new Date(); from.setDate(from.getDate() - 29); from.setHours(0, 0, 0, 0);
  const [{ data: orders }, { data: expenseRows }, { data: itemRows }, { data: stock }] = await Promise.all([
    supabase.from("orders").select("order_number,total_amount,discount_amount,status,created_at").gte("created_at", from.toISOString()).neq("status", "cancelled").order("created_at", { ascending: false }),
    supabase.from("expenses").select("amount").gte("expense_date", from.toISOString().slice(0, 10)),
    supabase.from("order_items").select("product_name,quantity,total_price,product:products(cost_price),order:orders!inner(status,created_at)").gte("order.created_at", from.toISOString()).neq("order.status", "cancelled"),
    supabase.from("ingredients").select("name,stock_quantity,reorder_level,unit,cost_per_unit").eq("is_active", true)
  ]);
  const grouped = new Map<string, { name: string; quantity: number; revenue: number; cost: number }>();
  for (const row of itemRows ?? []) { const entry = grouped.get(row.product_name) ?? { name: row.product_name, quantity: 0, revenue: 0, cost: 0 }; entry.quantity += Number(row.quantity); entry.revenue += Number(row.total_price); const product = Array.isArray(row.product) ? row.product[0] : row.product; entry.cost += Number(product?.cost_price ?? 0) * Number(row.quantity); grouped.set(row.product_name, entry); }
  return <ReportsDashboard orders={orders ?? []} expenses={(expenseRows ?? []).reduce((sum, row) => sum + Number(row.amount), 0)} products={[...grouped.values()].sort((a, b) => b.quantity - a.quantity)} stock={stock ?? []}/>;
}
