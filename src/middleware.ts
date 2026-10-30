import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  // Allow the Phase 1 dashboard UI to run before a Supabase project is configured.
  // Authentication is enforced automatically as soon as both values are supplied.
  if (!supabaseUrl || !supabaseAnonKey) return response;

  try {
    const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
      cookies: { getAll: () => request.cookies.getAll(), setAll: (items: Array<{ name: string; value: string; options: any }>) => { items.forEach(({ name, value }) => request.cookies.set(name, value)); response = NextResponse.next({ request }); items.forEach(({ name, value, options }) => response.cookies.set(name, value, options)); } }
    });
    const { data: { user } } = await supabase.auth.getUser();
    if (!user && request.nextUrl.pathname.startsWith("/dashboard")) return NextResponse.redirect(new URL("/login", request.url));
    if (user && request.nextUrl.pathname === "/login") return NextResponse.redirect(new URL("/dashboard", request.url));
  } catch {
    // A bad/missing deployment environment must not crash Vercel's edge middleware.
    return NextResponse.redirect(new URL("/login?configuration=invalid", request.url));
  }
  return response;
}
export const config = { matcher: ["/dashboard/:path*", "/login"] };
