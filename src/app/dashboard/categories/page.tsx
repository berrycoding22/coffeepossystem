import { CategoryManager } from "@/components/catalog/category-manager";
import { createClient } from "@/lib/supabase/server";
export default async function CategoriesPage() { const supabase = await createClient(); const { data } = await supabase.from("categories").select("id,name,khmer_name,is_active,sort_order").eq("is_active", true).order("sort_order"); return <CategoryManager categories={data ?? []}/>; }
