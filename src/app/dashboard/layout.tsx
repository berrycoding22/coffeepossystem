import { Sidebar } from "@/components/dashboard/sidebar";
import { Topbar } from "@/components/dashboard/topbar";
import { MobileNav } from "@/components/dashboard/mobile-nav";
export default function DashboardLayout({ children }: { children: React.ReactNode }) { return <div><Sidebar/><main className="pb-20 md:ml-64 md:pb-0"><Topbar/>{children}</main><MobileNav/></div>; }
