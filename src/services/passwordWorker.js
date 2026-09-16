const { parentPort } = require('node:worker_threads');
const bcrypt = require('bcryptjs');

// bcryptjs performs CPU work in JavaScript, even through its asynchronous API.
// Keep that work off the HTTP event loop without changing existing bcrypt hashes.
parentPort.on('message', ({ operation, password, hash }) => {
  try {
    const result = operation === 'hash'
      ? bcrypt.hashSync(password, 10)
      : bcrypt.compareSync(password, hash);
    parentPort.postMessage({ result });
  } catch (error) {
    parentPort.postMessage({ error: error.message });
  }
});
