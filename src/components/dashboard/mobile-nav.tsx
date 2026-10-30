"use client";
import Link from "next/link";
import { ClipboardList, LayoutDashboard, ShoppingBag, UtensilsCrossed } from "lucide-react";
import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
const links = [{ href: "/dashboard", label: "Home", icon: LayoutDashboard }, { href: "/dashboard/pos", label: "POS", icon: ShoppingBag }, { href: "/dashboard/orders", label: "Orders", icon: ClipboardList }, { href: "/dashboard/kitchen", label: "Kitchen", icon: UtensilsCrossed }];
export function MobileNav() { const path = usePathname(); const [role, setRole] = useState<string | null>(null); useEffect(() => { const supabase = createClient(); supabase.auth.getUser().then(async ({ data: { user } }) => { if (!user) return; const { data } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle(); setRole(data?.role ?? null); }); }, []); const visible = links.filter(link => role !== "barista" || link.href === "/dashboard/kitchen"); return <nav className="fixed inset-x-0 bottom-0 z-30 flex justify-around border-t border-[#eadfd4] bg-white/95 px-2 pb-[max(.5rem,env(safe-area-inset-bottom))] pt-2 shadow-[0_-8px_24px_rgba(75,46,43,.08)] md:hidden">{visible.map(link => { const Icon = link.icon; const active = path === link.href; return <Link key={link.href} href={link.href} className={`flex min-w-14 flex-col items-center gap-1 rounded-xl px-3 py-1.5 text-[10px] font-semibold ${active ? "text-espresso" : "text-stone-400"}`}><Icon className="size-5"/>{link.label}</Link>; })}</nav>; }
