import { OrderBoard } from "@/components/orders/order-board";
import { createClient } from "@/lib/supabase/server";
export default async function KitchenPage() { const supabase = await createClient(); const { data } = await supabase.from("orders").select("id,order_number,status,total_amount,order_type,notes,created_at,order_items(product_name,quantity)").in("status", ["pending","preparing","ready"]).order("created_at").limit(80); return <OrderBoard initialOrders={(data ?? []) as never} kitchen/>; }
