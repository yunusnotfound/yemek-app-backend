const router = require('express').Router();

router.use('/auth', require('./auth'));
router.use('/users', require('./users'));
router.use('/categories', require('./categories'));
router.use('/businesses', require('./businesses'));
router.use('/packages', require('./packages'));
router.use('/orders', require('./orders'));
router.use('/payments', require('./payments'));
router.use('/cards', require('./cards'));
router.use('/reviews', require('./reviews'));
router.use('/favorites', require('./favorites'));
router.use('/notifications', require('./notifications'));
router.use('/coupons', require('./coupons'));
router.use('/admin', require('./admin'));
router.use('/maps', require('./maps'));
router.use('/business-dashboard', require('./businessDashboard'));
router.use('/upload', require('./upload'));

module.exports = router;
