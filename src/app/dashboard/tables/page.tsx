import { TableFloor } from "@/components/tables/table-floor";
import { createClient } from "@/lib/supabase/server";
export default async function TablesPage() { const supabase = await createClient(); const { data } = await supabase.from("cafe_tables").select("id,table_number,seats,status").order("table_number"); return <TableFloor tables={(data ?? []) as never}/>; }
