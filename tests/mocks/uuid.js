// uuid v13 ESM-only olduğundan Jest'in (CJS) transform'u parse edemiyor.
// Uygulama yalnızca v4 kullanıyor; Node'un crypto.randomUUID'i geçerli bir v4
// UUID üretir. Bu shim sadece testlerde (jest moduleNameMapper) devreye girer.
const { randomUUID } = require('crypto');

module.exports = { v4: () => randomUUID() };
