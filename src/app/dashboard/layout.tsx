import { Sidebar } from "@/components/dashboard/sidebar";
import { Topbar } from "@/components/dashboard/topbar";
export default function DashboardLayout({ children }: { children: React.ReactNode }) { return <div><Sidebar/><main className="md:ml-64"><Topbar/>{children}</main></div>; }
