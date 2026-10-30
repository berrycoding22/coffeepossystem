import { InventoryManager } from "@/components/inventory/inventory-manager";
import { createClient } from "@/lib/supabase/server";
export default async function InventoryPage() { const supabase = await createClient(); const { data } = await supabase.from("ingredients").select("id,name,unit,stock_quantity,reorder_level,cost_per_unit").eq("is_active", true).order("name"); return <InventoryManager ingredients={data ?? []}/>; }
