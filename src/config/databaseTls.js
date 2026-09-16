// Sequelize parses DATABASE_URL after merging dialectOptions. Enforce the trust
// policy at connection time, so sslmode/no-verify cannot replace it or erase CA.
const isDatabaseTlsRequired = () => {
  if (process.env.DB_SSL === 'true') return true;
  if (!process.env.DATABASE_URL) return false;
  const params = new URL(process.env.DATABASE_URL).searchParams;
  const mode = params.get('sslmode');
  return Boolean((mode && mode !== 'disable') || params.get('ssl') === 'true' || params.has('sslrootcert'));
};

const enforceDatabaseTls = (config) => {
  const existing = config.dialectOptions?.ssl;
  if (!existing && !isDatabaseTlsRequired()) return;
  config.dialectOptions = config.dialectOptions || {};
  config.dialectOptions.ssl = {
    ...(typeof existing === 'object' ? existing : {}),
    rejectUnauthorized: true,
    ...(process.env.DB_CA_CERT ? { ca: process.env.DB_CA_CERT } : {}),
  };
};

module.exports = { enforceDatabaseTls, isDatabaseTlsRequired };
