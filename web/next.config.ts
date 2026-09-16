import path from "node:path";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Küçük, bağımsız Docker imajı için (web/Dockerfile bunu kopyalar)
  output: "standalone",
  // Monorepo: standalone dosya izlemeyi web/ ile sınırla (kökteki backend
  // lockfile'ı tracing root'u yukarı kaydırmasın).
  outputFileTracingRoot: path.join(__dirname),
  // Existing pages use plain <img>. Disable the unused server-side remote
  // image fetcher instead of exposing an arbitrary-host optimization endpoint.
  images: { unoptimized: true },
};

export default nextConfig;
