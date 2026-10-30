import { SettingsManager } from "@/components/admin/settings-manager";
import { createClient } from "@/lib/supabase/server";
const defaults = { shop_name: "CoffeeFlow POS", shop_address: null, phone: null, tax_rate: 0, exchange_rate: 4100, receipt_footer: "Thank you! Please come again!", default_order_type: "takeaway" as const, language: "en" as const };
export default async function SettingsPage() { const supabase = await createClient(); const { data } = await supabase.from("store_settings").select("shop_name,shop_address,phone,tax_rate,exchange_rate,receipt_footer,default_order_type,language").eq("id", true).maybeSingle(); return <SettingsManager initial={(data ?? defaults) as typeof defaults}/>; }
