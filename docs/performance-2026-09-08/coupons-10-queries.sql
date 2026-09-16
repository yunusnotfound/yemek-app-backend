SELECT "id", "name", "email", "password", "phone", "role", "latitude", "longitude", "isEmailVerified", "emailVerificationToken", "passwordResetToken", "passwordResetExpires", "passwordResetAttempts", "authVersion", "emailVerificationExpires", "googleId", "appleId", "cardUserKey", "createdAt", "updatedAt", "deletedAt" FROM "Users" AS "User" WHERE ("User"."deletedAt" IS NULL AND "User"."id" = 'daf178c0-e21a-498d-900c-60294ad5424f');

SELECT "title", "firstOrderOnly", "perUserLimit", "maxDiscountAmount", "budgetLimit", "isDiscoverable", "businessIds", "merchantConsentConfirmed", "id", "code", "discountType", "discountValue", "minOrderAmount", "maxUsage", "currentUsage", "expiresAt", "isActive", "createdAt", "updatedAt" FROM "Coupons" AS "Coupon" WHERE "Coupon"."isActive" = true AND "Coupon"."isDiscoverable" = true AND "Coupon"."expiresAt" > '2026-09-08 00:03:09.736 +00:00' ORDER BY "Coupon"."firstOrderOnly" DESC, "Coupon"."expiresAt" ASC LIMIT 100;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = 'daf178c0-e21a-498d-900c-60294ad5424f' AND "Order"."couponId" = '0af9c084-ef74-4222-9ab2-0cf0f9ac381b' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '0af9c084-ef74-4222-9ab2-0cf0f9ac381b' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '0af9c084-ef74-4222-9ab2-0cf0f9ac381b' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = 'daf178c0-e21a-498d-900c-60294ad5424f' AND "Order"."couponId" = 'ee370271-0735-4352-b501-53d3612892b0' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'ee370271-0735-4352-b501-53d3612892b0' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'ee370271-0735-4352-b501-53d3612892b0' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = 'daf178c0-e21a-498d-900c-60294ad5424f' AND "Order"."couponId" = 'eecc5abb-3177-43b3-90a6-123f752b1484' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'eecc5abb-3177-43b3-90a6-123f752b1484' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'eecc5abb-3177-43b3-90a6-123f752b1484' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = 'daf178c0-e21a-498d-900c-60294ad5424f' AND "Order"."couponId" = '5228c944-1b47-41bb-8ab5-098e88b711b4' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5228c944-1b47-41bb-8ab5-098e88b711b4' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5228c944-1b47-41bb-8ab5-098e88b711b4' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = 'daf178c0-e21a-498d-900c-60294ad5424f' AND "Order"."couponId" = '5ad1bd5c-abe7-40f2-8bce-aadf12c62de1' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5ad1bd5c-abe7-40f2-8bce-aadf12c62de1' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5ad1bd5c-abe7-40f2-8bce-aadf12c62de1' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = 'daf178c0-e21a-498d-900c-60294ad5424f' AND "Order"."couponId" = '3d3cf48a-beff-4261-b98d-8927f480d78c' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '3d3cf48a-beff-4261-b98d-8927f480d78c' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '3d3cf48a-beff-4261-b98d-8927f480d78c' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = 'daf178c0-e21a-498d-900c-60294ad5424f' AND "Order"."couponId" = 'c7df6e0b-6214-4122-9411-ecef31135758' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c7df6e0b-6214-4122-9411-ecef31135758' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c7df6e0b-6214-4122-9411-ecef31135758' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = 'daf178c0-e21a-498d-900c-60294ad5424f' AND "Order"."couponId" = '03335560-0057-4943-a56a-85addbcf2bf2' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '03335560-0057-4943-a56a-85addbcf2bf2' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '03335560-0057-4943-a56a-85addbcf2bf2' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = 'daf178c0-e21a-498d-900c-60294ad5424f' AND "Order"."couponId" = 'f69e3716-9991-4e3b-a89d-3a2dc1b3e324' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'f69e3716-9991-4e3b-a89d-3a2dc1b3e324' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'f69e3716-9991-4e3b-a89d-3a2dc1b3e324' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = 'daf178c0-e21a-498d-900c-60294ad5424f' AND "Order"."couponId" = '3aeb9e88-fee8-4029-927b-3863c7bcd2b7' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '3aeb9e88-fee8-4029-927b-3863c7bcd2b7' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '3aeb9e88-fee8-4029-927b-3863c7bcd2b7' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT
      COALESCE(SUM(quantity), 0)::int AS "rescuedPackages",
      COALESCE(SUM(GREATEST(COALESCE("originalTotal", "totalPrice") - "finalPrice", 0)), 0) AS "totalSaved"
      FROM "Orders" WHERE "userId" = 'daf178c0-e21a-498d-900c-60294ad5424f' AND status = 'picked_up'
      AND "paymentStatus" IN ('paid', 'unpaid')