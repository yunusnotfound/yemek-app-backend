import path from "node:path";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Explicit LAN origins for development on a TV/phone; production is unchanged.
  allowedDevOrigins: process.env.DEV_ALLOWED_ORIGINS?.split(",")
    .map((origin) => origin.trim())
    .filter(Boolean),
  devIndicators: process.env.DEV_ALLOWED_ORIGINS ? false : undefined,
  // Küçük, bağımsız Docker imajı için (web/Dockerfile bunu kopyalar)
  output: "standalone",
  // Monorepo: standalone dosya izlemeyi web/ ile sınırla (kökteki backend
  // lockfile'ı tracing root'u yukarı kaydırmasın).
  outputFileTracingRoot: path.join(__dirname),
  outputFileTracingIncludes: {
    "/api/admin/operations": ["./src/lib/operations/collect-operations.py"],
  },
  // Existing pages use plain <img>. Disable the unused server-side remote
  // image fetcher instead of exposing an arbitrary-host optimization endpoint.
  images: { unoptimized: true },
};

export default nextConfig;
