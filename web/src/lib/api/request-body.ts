import { NextResponse } from "next/server";

export class BodyLimitError extends Error {}

// Enforce the limit while streaming, even when Content-Length is absent/false.
export async function readLimitedBody(req: Request, maxBytes: number): Promise<Uint8Array<ArrayBuffer>> {
  if (Number(req.headers.get("content-length")) > maxBytes) throw new BodyLimitError();
  const reader = req.body?.getReader();
  if (!reader) return new Uint8Array();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBytes) { await reader.cancel(); throw new BodyLimitError(); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const body = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.byteLength; }
  return body;
}

export async function parseJsonRequest(req: Request) {
  try {
    const bytes = await readLimitedBody(req, 10 * 1024);
    const body = JSON.parse(new TextDecoder().decode(bytes));
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error();
    return { body };
  } catch (error) {
    return { response: NextResponse.json({ message: "Geçersiz veya fazla büyük istek" },
      { status: error instanceof BodyLimitError ? 413 : 400 }) };
  }
}
