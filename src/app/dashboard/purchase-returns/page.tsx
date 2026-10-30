import { PurchaseReturnManager } from "@/components/inventory/purchase-return-manager";
import { createClient } from "@/lib/supabase/server";
export default async function PurchaseReturnsPage() { const supabase = await createClient(); const { data } = await supabase.from("purchases").select("id,purchase_number,total_amount,return_amount,supplier:suppliers(name),purchase_items(id,received_quantity,unit_cost,ingredient:ingredients(name,unit))").eq("status", "received").order("received_at", { ascending: false }).limit(100); return <PurchaseReturnManager purchases={(data ?? []) as never}/>; }
