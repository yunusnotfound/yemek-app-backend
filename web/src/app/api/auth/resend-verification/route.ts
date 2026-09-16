import { parseJsonRequest } from "@/lib/api/request-body";
import { NextResponse } from "next/server";
import { callBackendJson } from "@/lib/api/client";

export async function POST(req: Request) {
  const parsed = await parseJsonRequest(req);
  if (parsed.response) return parsed.response;
  const body = parsed.body;
  const res = await callBackendJson("/auth/resend-verification", "POST", {
    email: body.email,
  });
  const data = await res.json().catch(() => null);
  return NextResponse.json(data ?? {}, { status: res.status });
}
