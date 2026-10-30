import { SupplierPayablesManager } from "@/components/inventory/supplier-payables-manager";
import { createClient } from "@/lib/supabase/server";
export default async function PayablesPage() { const supabase = await createClient(); const { data } = await supabase.from("purchases").select("id,purchase_number,total_amount,amount_paid,return_amount,payment_status,received_at,supplier:suppliers(name)").eq("status", "received").order("received_at", { ascending: false }); return <SupplierPayablesManager bills={(data ?? []) as never}/>; }
