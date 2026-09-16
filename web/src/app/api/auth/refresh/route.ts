import { NextResponse } from "next/server";
import { refreshSession } from "@/lib/auth/refresh";

export async function POST() {
  const token = await refreshSession();
  return NextResponse.json({ ok: Boolean(token) }, { status: token ? 200 : 401 });
}
