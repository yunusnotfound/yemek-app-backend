// Test ortamı env varsayılanları. Jest'in setupFiles'ı olarak (her worker'da,
// src require'larından ÖNCE) ve globalSetup başında require edilir.
process.env.NODE_ENV = 'test';

process.env.JWT_SECRET =
  process.env.JWT_SECRET || 'test-jwt-secret-please-change-000000000000';
process.env.JWT_REFRESH_SECRET =
  process.env.JWT_REFRESH_SECRET || 'test-jwt-refresh-secret-change-0000000000';
process.env.JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '15m';
process.env.JWT_REFRESH_EXPIRES_IN = process.env.JWT_REFRESH_EXPIRES_IN || '7d';

// Testler DAİMA ayrı bir test veritabanı kullanır (DB_*). DATABASE_URL bilerek
// devre dışı bırakılır ki geliştiricinin dev DATABASE_URL'i yanlışlıkla
// sync({force:true}) ile dev verisini SİLMESİN.
delete process.env.DATABASE_URL;
process.env.DB_HOST = process.env.DB_HOST || 'localhost';
process.env.DB_PORT = process.env.DB_PORT || '5432';
process.env.DB_USER = process.env.DB_USER || 'postgres';
process.env.DB_PASSWORD = process.env.DB_PASSWORD || 'postgres';
// DB_NAME DAİMA test DB'sine sabitlenir — miras alınan bir dev DB_NAME'i (ör.
// bitir_yemek) sync({force:true}) ile silmeyi önlemek için asla inherit edilmez.
process.env.DB_NAME = process.env.TEST_DB_NAME || 'bitir_yemek_test';
