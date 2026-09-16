const validate = (schema) => (req, res, next) => {
  const result = schema.safeParse(req.body);

  if (!result.success) {
    const errors = result.error.issues.map((err) => ({
      field: err.path.join('.'),
      message: err.message,
    }));

    return res.status(400).json({
      message: 'Doğrulama hatası',
      errors,
    });
  }

  req.body = result.data;
  next();
};

const validateQuery = (schema) => (req, res, next) => {
  const result = schema.safeParse(req.query);

  if (!result.success) {
    const errors = result.error.issues.map((err) => ({
      field: err.path.join('.'),
      message: err.message,
    }));

    return res.status(400).json({
      message: 'Query parametre hatası',
      errors,
    });
  }

  // Express 5 exposes query as a getter; assignment is silently ignored.
  Object.defineProperty(req, 'query', { value: result.data, writable: true, configurable: true });
  next();
};

const validateParams = (schema) => (req, res, next) => {
  const result = schema.safeParse(req.params);

  if (!result.success) {
    const errors = result.error.issues.map((err) => ({
      field: err.path.join('.'),
      message: err.message,
    }));

    return res.status(400).json({
      message: 'Parametre hatası',
      errors,
    });
  }

  req.params = result.data;
  next();
};

module.exports = { validate, validateQuery, validateParams };
