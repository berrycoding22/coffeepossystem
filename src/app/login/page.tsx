"use client";
import { Coffee, LockKeyhole, Mail } from "lucide-react";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { toast } from "sonner";

export default function LoginPage() {
  const [loading, setLoading] = useState(false);
  async function signIn(form: FormData) { setLoading(true); const supabase = createClient(); const { error } = await supabase.auth.signInWithPassword({ email: String(form.get("email")), password: String(form.get("password")) }); setLoading(false); if (error) toast.error(error.message); else location.assign("/dashboard"); }
  return <main className="min-h-screen bg-[radial-gradient(circle_at_top_right,_#e8d9c2,_#f8f5f0_45%)] grid place-items-center p-6"><section className="panel w-full max-w-md p-8"><div className="mb-8"><div className="mb-5 grid size-12 place-items-center rounded-2xl bg-espresso text-gold"><Coffee /></div><h1 className="text-2xl font-bold text-espresso">Welcome back</h1><p className="mt-2 text-sm text-stone-500">Sign in to CoffeeFlow POS</p></div><form action={signIn} className="space-y-4"><label className="block text-sm font-medium">Email<div className="relative mt-1"><Mail className="absolute left-3 top-3 size-4 text-stone-400"/><input required name="email" type="email" className="w-full rounded-xl border py-2.5 pl-10 pr-3 outline-none focus:border-gold" placeholder="you@coffeeflow.com"/></div></label><label className="block text-sm font-medium">Password<div className="relative mt-1"><LockKeyhole className="absolute left-3 top-3 size-4 text-stone-400"/><input required name="password" type="password" className="w-full rounded-xl border py-2.5 pl-10 pr-3 outline-none focus:border-gold" placeholder="••••••••"/></div></label><button disabled={loading} className="w-full rounded-xl bg-espresso py-3 font-semibold text-white transition hover:bg-[#37211f] disabled:opacity-60">{loading ? "Signing in…" : "Sign in"}</button></form><button className="mt-5 text-sm text-espresso underline">Forgot password?</button></section></main>;
}
