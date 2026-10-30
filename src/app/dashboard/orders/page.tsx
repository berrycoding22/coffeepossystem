import { OrderBoard } from "@/components/orders/order-board";
import { createClient } from "@/lib/supabase/server";
export default async function OrdersPage() { const supabase = await createClient(); const { data } = await supabase.from("orders").select("id,order_number,status,total_amount,order_type,notes,created_at,order_items(product_name,quantity)").order("created_at", { ascending: false }).limit(80); return <OrderBoard initialOrders={(data ?? []) as never}/>; }
