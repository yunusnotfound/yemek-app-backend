// Tüm testlerden ÖNCE bir kez çalışır: test veritabanını (yoksa) oluşturur ve
// şemayı sıfırdan (sync force) kurar. Böylece `npm test` yerelde compose
// Postgres'ine karşı ekstra kurulum olmadan çalışır.
require('./env');
const { Client } = require('pg');

module.exports = async () => {
  const dbName = process.env.DB_NAME;

  // Test DB'sini yoksa oluştur (bakım DB'si 'postgres' üzerinden bağlanarak).
  const admin = new Client({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: 'postgres',
  });
  await admin.connect();
  const { rowCount } = await admin.query(
    'SELECT 1 FROM pg_database WHERE datname = $1',
    [dbName],
  );
  if (rowCount === 0) {
    await admin.query(`CREATE DATABASE "${dbName}"`);
  }
  await admin.end();

  // Şemayı temiz kur (model tanımlarından). Migration'a özgü kısmi indeksler
  // testler için gerekmiyor; controller mantığını doğruluyoruz.
  const sequelize = require('../src/config/database');
  require('../src/models'); // tüm modeller + ilişkiler
  await sequelize.sync({ force: true });
  await sequelize.close();
};
