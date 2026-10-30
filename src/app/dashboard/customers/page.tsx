import { CustomerManager } from "@/components/sales/customer-manager";
import { createClient } from "@/lib/supabase/server";
export default async function CustomersPage() { const supabase = await createClient(); const { data } = await supabase.from("customers").select("id,code,full_name,phone,email,credit_limit,credit_balance,is_active").eq("is_active", true).order("full_name"); return <CustomerManager customers={data ?? []}/>; }
