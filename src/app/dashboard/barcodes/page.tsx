import { BarcodeLabelManager } from "@/components/catalog/barcode-label-manager";
import { createClient } from "@/lib/supabase/server";
export default async function BarcodesPage() { const supabase = await createClient(); const { data } = await supabase.from("products").select("id,name,barcode,sku,base_price").eq("is_active", true).order("name"); return <BarcodeLabelManager products={data ?? []}/>; }
