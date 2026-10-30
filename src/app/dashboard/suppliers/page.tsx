import { SupplierManager } from "@/components/inventory/supplier-manager";
import { createClient } from "@/lib/supabase/server";
export default async function SuppliersPage() { const supabase = await createClient(); const { data } = await supabase.from("suppliers").select("id,name,phone,email,address").eq("is_active", true).order("name"); return <SupplierManager suppliers={data ?? []}/>; }
