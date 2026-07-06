module.exports = {
  testEnvironment: 'node',
  // env.js, herhangi bir src modülü (models/app) require edilmeden ÖNCE env'i kurar.
  setupFiles: ['<rootDir>/tests/env.js'],
  // Şemayı tüm testlerden önce bir kez oluşturur.
  globalSetup: '<rootDir>/tests/globalSetup.js',
  testMatch: ['<rootDir>/tests/**/*.test.js'],
  // uuid v13 ESM-only; testlerde CJS shim'e yönlendir (bkz. tests/mocks/uuid.js).
  moduleNameMapper: {
    '^uuid$': '<rootDir>/tests/mocks/uuid.js',
  },
  testTimeout: 30000,
  // DB entegrasyon testleri — çakışmayı önlemek için seri çalıştır.
  maxWorkers: 1,
  // Sequelize/ioredis havuzları açık kalır; Jest'in temiz çıkmasını sağla.
  forceExit: true,
};
