import { EmployeeManager } from "@/components/admin/employee-manager";
import { createClient } from "@/lib/supabase/server";
export default async function EmployeesPage() { const supabase = await createClient(); const { data } = await supabase.from("profiles").select("id,full_name,phone,role,is_active,created_at").order("created_at"); return <EmployeeManager employees={data ?? []}/>; }
