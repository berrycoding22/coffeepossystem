import { BranchWarehouseManager } from "@/components/inventory/branch-warehouse-manager";
import { createClient } from "@/lib/supabase/server";

export default async function LocationsPage() {
  const supabase = await createClient();
  const [{ data: branches }, { data: warehouses }] = await Promise.all([
    supabase.from("branches").select("id,code,name,khmer_name,address,is_active").order("name"),
    supabase.from("warehouses").select("id,branch_id,code,name,khmer_name,address,is_active").order("name")
  ]);
  return <BranchWarehouseManager branches={branches ?? []} warehouses={warehouses ?? []}/>;
}
