import { NextResponse } from "next/server";
import { callBackendJson } from "@/lib/api/client";

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const res = await callBackendJson("/auth/reset-password", "POST", {
    token: body.token,
    password: body.password,
  });
  const data = await res.json().catch(() => null);
  return NextResponse.json(data ?? {}, { status: res.status });
}
