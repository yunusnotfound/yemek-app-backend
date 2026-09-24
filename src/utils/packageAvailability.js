const { Op, literal } = require('sequelize');

// Pickup windows are entered in Turkey's local time. End <= start denotes
// an overnight window, just as it does when accepting an order.
const column = (alias, name) => `"${alias.replaceAll('"', '""')}"."${name}"`;
const pickupEndSql = (alias) => `((
  ${column(alias, 'pickupDate')}::date + ${column(alias, 'pickupEnd')}::time +
  CASE WHEN ${column(alias, 'pickupEnd')}::time <= ${column(alias, 'pickupStart')}::time
    THEN INTERVAL '1 day' ELSE INTERVAL '0 day' END
) AT TIME ZONE 'Europe/Istanbul')`;

const availablePackageWhere = (alias = 'SurprisePackage') => ({
  isActive: true,
  isSuspended: false,
  remainingQuantity: { [Op.gt]: 0 },
  [Op.and]: [literal(`${pickupEndSql(alias)} > NOW()`)],
});

// Apply before LIMIT, otherwise empty/expired businesses consume map slots.
const hasAvailablePackages = (businessAlias = 'Business') => literal(`EXISTS (
  SELECT 1 FROM "SurprisePackages" AS "availablePackage"
  WHERE "availablePackage"."businessId" = ${column(businessAlias, 'id')}
    AND "availablePackage"."deletedAt" IS NULL
    AND "availablePackage"."isActive" = true
    AND "availablePackage"."isSuspended" = false
    AND "availablePackage"."remainingQuantity" > 0
    AND ${pickupEndSql('availablePackage')} > NOW()
)`);

const pickupStartAt = (pkg) => new Date(`${pkg.pickupDate}T${pkg.pickupStart}+03:00`);
const pickupEndAt = (pkg) => {
  const start = pickupStartAt(pkg);
  const end = new Date(`${pkg.pickupDate}T${pkg.pickupEnd}+03:00`);
  if (end <= start) end.setTime(end.getTime() + 86400000);
  return end;
};

// A clock change does not bump cache namespaces. Never keep a cached catalog
// beyond a pickup boundary, even if no stock or business edit occurred.
const availabilityCacheTtl = (packages, maxSeconds, now = Date.now()) => {
  let ttl = maxSeconds;
  for (const pkg of packages) {
    const end = pickupEndAt(pkg).getTime();
    if (!Number.isFinite(end)) return 0;
    ttl = Math.min(ttl, Math.floor((end - now) / 1000));
    const start = pickupStartAt(pkg).getTime();
    if (start > now) ttl = Math.min(ttl, Math.floor((start - now) / 1000));
  }
  return Math.max(0, ttl);
};

const AVAILABILITY_ATTRIBUTES = [
  'id', 'businessId', 'pickupDate', 'pickupStart', 'pickupEnd',
  'isActive', 'isSuspended', 'remainingQuantity',
];

module.exports = {
  pickupEndSql, availablePackageWhere, hasAvailablePackages,
  pickupStartAt, pickupEndAt, availabilityCacheTtl, AVAILABILITY_ATTRIBUTES,
};
