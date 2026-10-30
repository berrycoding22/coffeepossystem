import { EmployeeManager } from "@/components/admin/employee-manager";
import { createClient } from "@/lib/supabase/server";
export default async function EmployeesPage() { const supabase = await createClient(); const [{ data: employees }, { data: branches }] = await Promise.all([supabase.from("profiles").select("id,full_name,phone,role,is_active,created_at,branch_id").order("created_at"), supabase.from("branches").select("id,name").eq("is_active", true).order("name")]); return <EmployeeManager employees={employees ?? []} branches={branches ?? []}/>; }
