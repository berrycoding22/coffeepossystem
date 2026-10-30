import { ExpenseManager } from "@/components/admin/expense-manager";
import { createClient } from "@/lib/supabase/server";
export default async function ExpensesPage() { const supabase = await createClient(); const { data } = await supabase.from("expenses").select("id,category,amount,currency,expense_date,note").order("expense_date", { ascending: false }); return <ExpenseManager expenses={data ?? []}/>; }
