const { Sequelize } = require('sequelize');
const { enforceDatabaseTls, isDatabaseTlsRequired } = require('./databaseTls');

const isProduction = process.env.NODE_ENV === 'production';
const isTest = process.env.NODE_ENV === 'test';
const useSSL = isDatabaseTlsRequired();

const dbOptions = {
  hooks: { beforeConnect: enforceDatabaseTls },
  dialect: 'postgres',
  // Test'te de SQL loglamayı sustur (aksi halde test çıktısı okunamaz olur).
  logging: isProduction || isTest ? false : console.log,
  pool: {
    max: isProduction ? 20 : 20,
    min: isProduction ? 2 : 3,
    acquire: 30000,
    idle: 10000,
  },
  // Asılı kalan sorgular bağlantıları sonsuza kadar tutmasın
  dialectOptions: {
    statement_timeout: 30000,
    idle_in_transaction_session_timeout: 30000,
  },
};

// Only add SSL if explicitly required
if (useSSL) {
  dbOptions.dialectOptions.ssl = {
    require: true,
    rejectUnauthorized: true,
    ...(process.env.DB_CA_CERT ? { ca: process.env.DB_CA_CERT } : {}),
  };
}

let sequelize;
try {
  sequelize = process.env.DATABASE_URL
    ? new Sequelize(process.env.DATABASE_URL, dbOptions)
    : new Sequelize(
        process.env.DB_NAME,
        process.env.DB_USER,
        process.env.DB_PASSWORD,
        {
          host: process.env.DB_HOST,
          port: process.env.DB_PORT,
          ...dbOptions,
        }
      );
} catch (error) {
  console.error('Database initialization failed:', error.message);
  process.exit(1);
}

module.exports = sequelize;
