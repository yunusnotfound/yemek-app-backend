import { NextResponse } from "next/server";
import { callBackendJson } from "@/lib/api/client";
import { setSession } from "@/lib/auth/session";
import type { AuthResponse } from "@/lib/types";

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));

  const res = await callBackendJson("/auth/login", "POST", {
    email: body.email,
    password: body.password,
  });
  const data = await res.json().catch(() => null);

  if (!res.ok) {
    return NextResponse.json(data ?? { message: "Giriş başarısız" }, {
      status: res.status,
    });
  }

  const auth = data as AuthResponse;
  await setSession(auth.accessToken, auth.refreshToken);
  return NextResponse.json({ user: auth.user });
}
