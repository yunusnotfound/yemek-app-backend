require('dotenv').config();
const { enforceDatabaseTls, isDatabaseTlsRequired } = require('./databaseTls');

const useSSL = isDatabaseTlsRequired();

const sslOptions = useSSL
  ? {
      dialectOptions: {
        ssl: {
          require: true,
          rejectUnauthorized: true,
          ...(process.env.DB_CA_CERT ? { ca: process.env.DB_CA_CERT } : {}),
        },
      },
    }
  : {};

const production = process.env.DATABASE_URL
  ? {
      use_env_variable: 'DATABASE_URL',
      hooks: { beforeConnect: enforceDatabaseTls },
      dialect: 'postgres',
      ...sslOptions,
    }
  : {
      username: process.env.DB_USER,
      hooks: { beforeConnect: enforceDatabaseTls },
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      dialect: 'postgres',
      ...sslOptions,
    };

module.exports = {
  development: {
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    dialect: 'postgres',
  },
  production,
};
