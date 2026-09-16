import { parseJsonRequest } from "@/lib/api/request-body";
import { NextResponse } from "next/server";
import { callBackendJson } from "@/lib/api/client";
import type { AuthResponse } from "@/lib/types";

// Ownership is verified by email before a session can be issued.
export async function POST(req: Request) {
  const parsed = await parseJsonRequest(req);
  if (parsed.response) return parsed.response;
  const body = parsed.body;

  const res = await callBackendJson("/auth/register", "POST", {
    name: body.name,
    email: body.email,
    password: body.password,
    phone: body.phone || undefined,
    role: "business_owner",
  });
  const data = await res.json().catch(() => null);

  if (!res.ok) {
    return NextResponse.json(data ?? { message: "Kayıt başarısız" }, {
      status: res.status,
    });
  }

  const auth = data as AuthResponse;
  return NextResponse.json({ user: auth.user, message: auth.message });
}
