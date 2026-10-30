"use client";

import { FormEvent, useMemo, useState } from "react";
import { Building2, MapPin, Plus, Warehouse } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { toast } from "sonner";
import { useRouter } from "next/navigation";

type Branch = { id: string; code: string; name: string; khmer_name: string | null; address: string | null; is_active: boolean };
type WarehouseRow = { id: string; branch_id: string; code: string; name: string; khmer_name: string | null; address: string | null; is_active: boolean };

export function BranchWarehouseManager({ branches, warehouses }: { branches: Branch[]; warehouses: WarehouseRow[] }) {
  const router = useRouter();
  const [mode, setMode] = useState<"branch" | "warehouse" | null>(null);
  const warehouseByBranch = useMemo(() => new Map(branches.map(branch => [branch.id, warehouses.filter(warehouse => warehouse.branch_id === branch.id)])), [branches, warehouses]);

  async function createBranch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const { error } = await createClient().from("branches").insert({ code: String(form.get("code")).trim().toUpperCase(), name: String(form.get("name")).trim(), khmer_name: String(form.get("khmer_name")).trim() || null, address: String(form.get("address")).trim() || null });
    if (error) return toast.error(error.message);
    toast.success("Branch created"); setMode(null); router.refresh();
  }

  async function createWarehouse(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const { error } = await createClient().from("warehouses").insert({ branch_id: String(form.get("branch_id")), code: String(form.get("code")).trim().toUpperCase(), name: String(form.get("name")).trim(), khmer_name: String(form.get("khmer_name")).trim() || null, address: String(form.get("address")).trim() || null });
    if (error) return toast.error(error.message);
    toast.success("Warehouse created"); setMode(null); router.refresh();
  }

  return <div className="p-5 md:p-9">
    <div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="text-sm text-stone-500">Operate stock across locations</p><h1 className="text-3xl font-bold text-espresso">Branches & warehouses</h1><p className="mt-2 max-w-2xl text-sm text-stone-500">Each branch can have one or more warehouses. Your existing inventory is safely kept in Main Branch → Main Warehouse.</p></div><div className="flex gap-2"><button onClick={() => setMode(mode === "branch" ? null : "branch")} className="flex items-center gap-2 rounded-xl bg-espresso px-4 py-2.5 text-sm font-semibold text-white"><Plus className="size-4"/>Add branch</button><button onClick={() => setMode(mode === "warehouse" ? null : "warehouse")} className="flex items-center gap-2 rounded-xl border border-[#dfd1c4] bg-white px-4 py-2.5 text-sm font-semibold text-espresso"><Plus className="size-4"/>Add warehouse</button></div></div>

    {mode === "branch" && <form onSubmit={createBranch} className="panel mb-6 grid gap-3 p-5 md:grid-cols-2"><input required name="code" maxLength={20} placeholder="Branch code (e.g. PP-01)" className="rounded-xl border px-3 py-2.5"/><input required name="name" placeholder="Branch name" className="rounded-xl border px-3 py-2.5"/><input name="khmer_name" placeholder="ឈ្មោះសាខាជាខ្មែរ (optional)" className="rounded-xl border px-3 py-2.5"/><input name="address" placeholder="Address (optional)" className="rounded-xl border px-3 py-2.5"/><button className="rounded-xl bg-gold px-4 py-2.5 font-semibold text-white">Save branch</button></form>}
    {mode === "warehouse" && <form onSubmit={createWarehouse} className="panel mb-6 grid gap-3 p-5 md:grid-cols-2"><select required name="branch_id" className="rounded-xl border px-3 py-2.5"><option value="">Choose branch</option>{branches.filter(branch => branch.is_active).map(branch => <option key={branch.id} value={branch.id}>{branch.name}</option>)}</select><input required name="code" maxLength={30} placeholder="Warehouse code (e.g. PP-01-WH)" className="rounded-xl border px-3 py-2.5"/><input required name="name" placeholder="Warehouse name" className="rounded-xl border px-3 py-2.5"/><input name="khmer_name" placeholder="ឈ្មោះឃ្លាំងជាខ្មែរ (optional)" className="rounded-xl border px-3 py-2.5"/><input name="address" placeholder="Address (optional)" className="rounded-xl border px-3 py-2.5"/><button className="rounded-xl bg-gold px-4 py-2.5 font-semibold text-white">Save warehouse</button></form>}

    <div className="grid gap-5 lg:grid-cols-2">{branches.map(branch => <article className="panel p-5" key={branch.id}><div className="flex items-start justify-between gap-3"><div className="flex gap-3"><span className="grid size-10 shrink-0 place-items-center rounded-xl bg-[#f5ece2] text-espresso"><Building2 className="size-5"/></span><div><h2 className="font-bold text-espresso">{branch.name}</h2>{branch.khmer_name && <p className="text-sm text-stone-500">{branch.khmer_name}</p>}<p className="mt-1 text-xs text-stone-400">{branch.code}{branch.address ? ` · ${branch.address}` : ""}</p></div></div><span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${branch.is_active ? "bg-emerald-50 text-emerald-700" : "bg-stone-100 text-stone-500"}`}>{branch.is_active ? "Active" : "Inactive"}</span></div><div className="mt-5 border-t pt-4"><p className="mb-2 text-xs font-semibold uppercase tracking-wide text-stone-400">Warehouses</p>{(warehouseByBranch.get(branch.id) ?? []).map(warehouse => <div className="flex items-center gap-2 py-2 text-sm" key={warehouse.id}><Warehouse className="size-4 text-gold"/><span className="font-medium">{warehouse.name}</span><span className="text-xs text-stone-400">{warehouse.code}</span></div>)}{!(warehouseByBranch.get(branch.id) ?? []).length && <p className="flex items-center gap-2 py-2 text-sm text-stone-400"><MapPin className="size-4"/>No warehouse yet</p>}</div></article>)}{!branches.length && <div className="panel p-12 text-center text-sm text-stone-500">No branches yet.</div>}</div>
  </div>;
}
