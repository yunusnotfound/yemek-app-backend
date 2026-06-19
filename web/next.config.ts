import path from "node:path";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Küçük, bağımsız Docker imajı için (web/Dockerfile bunu kopyalar)
  output: "standalone",
  // Monorepo: standalone dosya izlemeyi web/ ile sınırla (kökteki backend
  // lockfile'ı tracing root'u yukarı kaydırmasın).
  outputFileTracingRoot: path.join(__dirname),
  // İşletme/paket görselleri API alan adından (uploads) gelir; harici barındırma da olabilir.
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "**" },
      { protocol: "http", hostname: "localhost" },
    ],
  },
};

export default nextConfig;
