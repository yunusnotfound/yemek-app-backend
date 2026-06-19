import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    rules: {
      // İşletme/paket görselleri API alan adından gelen uzak kullanıcı içeriğidir;
      // next/image optimizasyonu yerine bilinçli olarak <img> kullanıyoruz.
      "@next/next/no-img-element": "off",
      // Veri çekme effektlerinde bilinçli "yükleniyor durumuna sıfırla + fetch"
      // deseni kullanıyoruz; React Compiler'ın bu kuralı bu deseni hata sayıyor.
      "react-hooks/set-state-in-effect": "off",
    },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
  ]),
]);

export default eslintConfig;
