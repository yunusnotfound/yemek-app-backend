SELECT "id", "name", "email", "password", "phone", "role", "latitude", "longitude", "isEmailVerified", "emailVerificationToken", "passwordResetToken", "passwordResetExpires", "passwordResetAttempts", "authVersion", "emailVerificationExpires", "googleId", "appleId", "cardUserKey", "createdAt", "updatedAt", "deletedAt" FROM "Users" AS "User" WHERE ("User"."deletedAt" IS NULL AND "User"."id" = '9be973ab-62e1-438f-bd18-a69b8fb5af69');

SELECT "title", "firstOrderOnly", "perUserLimit", "maxDiscountAmount", "budgetLimit", "isDiscoverable", "businessIds", "merchantConsentConfirmed", "id", "code", "discountType", "discountValue", "minOrderAmount", "maxUsage", "currentUsage", "expiresAt", "isActive", "createdAt", "updatedAt" FROM "Coupons" AS "Coupon" WHERE "Coupon"."isActive" = true AND "Coupon"."isDiscoverable" = true AND "Coupon"."expiresAt" > '2026-09-08 00:03:10.924 +00:00' ORDER BY "Coupon"."firstOrderOnly" DESC, "Coupon"."expiresAt" ASC LIMIT 100;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '0af9c084-ef74-4222-9ab2-0cf0f9ac381b' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '0af9c084-ef74-4222-9ab2-0cf0f9ac381b' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '0af9c084-ef74-4222-9ab2-0cf0f9ac381b' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'ee370271-0735-4352-b501-53d3612892b0' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'ee370271-0735-4352-b501-53d3612892b0' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'ee370271-0735-4352-b501-53d3612892b0' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'eecc5abb-3177-43b3-90a6-123f752b1484' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'eecc5abb-3177-43b3-90a6-123f752b1484' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'eecc5abb-3177-43b3-90a6-123f752b1484' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '5228c944-1b47-41bb-8ab5-098e88b711b4' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5228c944-1b47-41bb-8ab5-098e88b711b4' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5228c944-1b47-41bb-8ab5-098e88b711b4' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '5ad1bd5c-abe7-40f2-8bce-aadf12c62de1' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5ad1bd5c-abe7-40f2-8bce-aadf12c62de1' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5ad1bd5c-abe7-40f2-8bce-aadf12c62de1' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '3d3cf48a-beff-4261-b98d-8927f480d78c' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '3d3cf48a-beff-4261-b98d-8927f480d78c' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '3d3cf48a-beff-4261-b98d-8927f480d78c' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'c7df6e0b-6214-4122-9411-ecef31135758' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c7df6e0b-6214-4122-9411-ecef31135758' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c7df6e0b-6214-4122-9411-ecef31135758' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '03335560-0057-4943-a56a-85addbcf2bf2' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '03335560-0057-4943-a56a-85addbcf2bf2' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '03335560-0057-4943-a56a-85addbcf2bf2' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'f69e3716-9991-4e3b-a89d-3a2dc1b3e324' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'f69e3716-9991-4e3b-a89d-3a2dc1b3e324' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'f69e3716-9991-4e3b-a89d-3a2dc1b3e324' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '3aeb9e88-fee8-4029-927b-3863c7bcd2b7' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '3aeb9e88-fee8-4029-927b-3863c7bcd2b7' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '3aeb9e88-fee8-4029-927b-3863c7bcd2b7' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'ba8c3b30-11f0-4b5b-800e-8cbe58832345' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'ba8c3b30-11f0-4b5b-800e-8cbe58832345' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'ba8c3b30-11f0-4b5b-800e-8cbe58832345' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'cd747028-76d1-472c-b7b9-2fcaeb56affe' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'cd747028-76d1-472c-b7b9-2fcaeb56affe' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'cd747028-76d1-472c-b7b9-2fcaeb56affe' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'b115af34-4ae7-43c1-a222-29d122c940a8' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'b115af34-4ae7-43c1-a222-29d122c940a8' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'b115af34-4ae7-43c1-a222-29d122c940a8' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'c5272a27-03c0-41fb-afd0-dd0e34f4b19f' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c5272a27-03c0-41fb-afd0-dd0e34f4b19f' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c5272a27-03c0-41fb-afd0-dd0e34f4b19f' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '65a96b1c-d1f5-4e20-b567-24c2f4679a1b' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '65a96b1c-d1f5-4e20-b567-24c2f4679a1b' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '65a96b1c-d1f5-4e20-b567-24c2f4679a1b' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '82733ccd-4330-4ce8-bdb7-8bdabf66bade' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '82733ccd-4330-4ce8-bdb7-8bdabf66bade' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '82733ccd-4330-4ce8-bdb7-8bdabf66bade' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '940d5da0-0926-494a-ad98-65b58e43f2df' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '940d5da0-0926-494a-ad98-65b58e43f2df' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '940d5da0-0926-494a-ad98-65b58e43f2df' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'c2cb1be6-1b8d-4c30-a713-1b00afcdaf00' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c2cb1be6-1b8d-4c30-a713-1b00afcdaf00' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c2cb1be6-1b8d-4c30-a713-1b00afcdaf00' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '781e7a1e-a5c7-4ca3-8ee0-296dbba9f30d' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '781e7a1e-a5c7-4ca3-8ee0-296dbba9f30d' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '781e7a1e-a5c7-4ca3-8ee0-296dbba9f30d' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'c588b4d3-ea48-4171-a7bf-9ada65f8c3e3' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c588b4d3-ea48-4171-a7bf-9ada65f8c3e3' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c588b4d3-ea48-4171-a7bf-9ada65f8c3e3' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'a29ceea7-0a83-4c76-9d09-dde27f696c01' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'a29ceea7-0a83-4c76-9d09-dde27f696c01' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'a29ceea7-0a83-4c76-9d09-dde27f696c01' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '46f0144e-288b-4715-961c-2e6eaec14b68' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '46f0144e-288b-4715-961c-2e6eaec14b68' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '46f0144e-288b-4715-961c-2e6eaec14b68' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '2a42a8c4-e5cb-449d-b946-fd4ff979bf6d' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '2a42a8c4-e5cb-449d-b946-fd4ff979bf6d' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '2a42a8c4-e5cb-449d-b946-fd4ff979bf6d' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '2559f5bb-1bab-4d4b-8f48-1ae0903f10ab' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '2559f5bb-1bab-4d4b-8f48-1ae0903f10ab' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '2559f5bb-1bab-4d4b-8f48-1ae0903f10ab' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '6d980fd7-1c2c-4e74-8fc0-2dcff56b076b' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '6d980fd7-1c2c-4e74-8fc0-2dcff56b076b' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '6d980fd7-1c2c-4e74-8fc0-2dcff56b076b' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '0aa5d43f-02e9-46c4-8b06-db7c26d1a2c6' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '0aa5d43f-02e9-46c4-8b06-db7c26d1a2c6' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '0aa5d43f-02e9-46c4-8b06-db7c26d1a2c6' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '6c12c19d-59d7-4e80-8c4b-05b3e0aa8421' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '6c12c19d-59d7-4e80-8c4b-05b3e0aa8421' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '6c12c19d-59d7-4e80-8c4b-05b3e0aa8421' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '0ed0726f-5535-41d2-9e10-50b0b240f229' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '0ed0726f-5535-41d2-9e10-50b0b240f229' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '0ed0726f-5535-41d2-9e10-50b0b240f229' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '1ab57345-c7c2-4df5-9344-d8072c38a3d9' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '1ab57345-c7c2-4df5-9344-d8072c38a3d9' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '1ab57345-c7c2-4df5-9344-d8072c38a3d9' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'a9313403-6bd6-490f-82b9-33b56033822d' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'a9313403-6bd6-490f-82b9-33b56033822d' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'a9313403-6bd6-490f-82b9-33b56033822d' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'dc8e0a20-d7fa-4d42-a59f-1a354ae61bf8' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'dc8e0a20-d7fa-4d42-a59f-1a354ae61bf8' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'dc8e0a20-d7fa-4d42-a59f-1a354ae61bf8' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '45a43f26-c3f9-4336-bdf9-8a3468d97ac1' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '45a43f26-c3f9-4336-bdf9-8a3468d97ac1' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '45a43f26-c3f9-4336-bdf9-8a3468d97ac1' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '79b27003-9ac7-4d79-96e5-e3f8361754b7' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '79b27003-9ac7-4d79-96e5-e3f8361754b7' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '79b27003-9ac7-4d79-96e5-e3f8361754b7' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '04668145-7ed9-49f7-8e92-4f2cc0746d09' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '04668145-7ed9-49f7-8e92-4f2cc0746d09' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '04668145-7ed9-49f7-8e92-4f2cc0746d09' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '9fd0da29-814c-437f-acbc-6109dd63530a' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '9fd0da29-814c-437f-acbc-6109dd63530a' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '9fd0da29-814c-437f-acbc-6109dd63530a' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'd1e38d6c-d7fb-4930-9d8a-15772e06cc1e' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'd1e38d6c-d7fb-4930-9d8a-15772e06cc1e' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'd1e38d6c-d7fb-4930-9d8a-15772e06cc1e' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '00d12966-3580-418f-99ce-3aa33a8d9748' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '00d12966-3580-418f-99ce-3aa33a8d9748' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '00d12966-3580-418f-99ce-3aa33a8d9748' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '7d2ee5aa-3939-4df0-b8a1-9a93364678fe' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '7d2ee5aa-3939-4df0-b8a1-9a93364678fe' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '7d2ee5aa-3939-4df0-b8a1-9a93364678fe' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '1a6f05cc-870c-4840-b0c2-d6af8ca8f4cb' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '1a6f05cc-870c-4840-b0c2-d6af8ca8f4cb' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '1a6f05cc-870c-4840-b0c2-d6af8ca8f4cb' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'cebc365a-7e40-43ee-8b77-289ffe0d2457' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'cebc365a-7e40-43ee-8b77-289ffe0d2457' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'cebc365a-7e40-43ee-8b77-289ffe0d2457' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'd6648668-4dc9-4dca-9874-06f5bc6dd536' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'd6648668-4dc9-4dca-9874-06f5bc6dd536' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'd6648668-4dc9-4dca-9874-06f5bc6dd536' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'e94e36e3-4693-4d6a-a61e-2e4726091be7' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'e94e36e3-4693-4d6a-a61e-2e4726091be7' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'e94e36e3-4693-4d6a-a61e-2e4726091be7' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '21c01d54-db87-4caa-b78b-b85134997f0f' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '21c01d54-db87-4caa-b78b-b85134997f0f' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '21c01d54-db87-4caa-b78b-b85134997f0f' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'd61eb622-bb89-486f-aec4-e52c74531ed6' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'd61eb622-bb89-486f-aec4-e52c74531ed6' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'd61eb622-bb89-486f-aec4-e52c74531ed6' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '26b5dbdf-9d7b-4a8e-a605-f498aeeeb120' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '26b5dbdf-9d7b-4a8e-a605-f498aeeeb120' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '26b5dbdf-9d7b-4a8e-a605-f498aeeeb120' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'bbc828c1-f76d-46b9-94a5-40fd965755bf' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'bbc828c1-f76d-46b9-94a5-40fd965755bf' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'bbc828c1-f76d-46b9-94a5-40fd965755bf' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '72a6d05a-c438-4a11-9e84-0c52b95cf19a' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '72a6d05a-c438-4a11-9e84-0c52b95cf19a' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '72a6d05a-c438-4a11-9e84-0c52b95cf19a' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '7a30e138-4e20-420b-8073-022e6a098d98' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '7a30e138-4e20-420b-8073-022e6a098d98' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '7a30e138-4e20-420b-8073-022e6a098d98' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'a84a5502-c66d-4e66-9570-acaac12e8721' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'a84a5502-c66d-4e66-9570-acaac12e8721' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'a84a5502-c66d-4e66-9570-acaac12e8721' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '06d8d810-bafc-4e50-862a-8b8977d77a52' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '06d8d810-bafc-4e50-862a-8b8977d77a52' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '06d8d810-bafc-4e50-862a-8b8977d77a52' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'ab39a823-c7b2-4867-b97b-23e94cef2dd8' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'ab39a823-c7b2-4867-b97b-23e94cef2dd8' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'ab39a823-c7b2-4867-b97b-23e94cef2dd8' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '35542df4-bf10-4df2-933b-9657f41c5cf0' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '35542df4-bf10-4df2-933b-9657f41c5cf0' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '35542df4-bf10-4df2-933b-9657f41c5cf0' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '28d25bc7-677b-4d40-90a3-2b4f420fe260' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '28d25bc7-677b-4d40-90a3-2b4f420fe260' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '28d25bc7-677b-4d40-90a3-2b4f420fe260' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '6453364a-b6be-46f0-9df8-5ad64802b480' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '6453364a-b6be-46f0-9df8-5ad64802b480' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '6453364a-b6be-46f0-9df8-5ad64802b480' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '3d88d8f7-bc65-4133-883d-bc6fb0089678' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '3d88d8f7-bc65-4133-883d-bc6fb0089678' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '3d88d8f7-bc65-4133-883d-bc6fb0089678' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'fef8945c-d8fb-4ea2-8ecc-c5c5f08973b9' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'fef8945c-d8fb-4ea2-8ecc-c5c5f08973b9' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'fef8945c-d8fb-4ea2-8ecc-c5c5f08973b9' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '61eecc38-861c-43e3-9828-533bc66c9e71' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '61eecc38-861c-43e3-9828-533bc66c9e71' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '61eecc38-861c-43e3-9828-533bc66c9e71' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '590edd9b-692b-4445-b2d2-494055d38735' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '590edd9b-692b-4445-b2d2-494055d38735' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '590edd9b-692b-4445-b2d2-494055d38735' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '2b37de1f-9ce9-4f66-95ec-04e19aa94772' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '2b37de1f-9ce9-4f66-95ec-04e19aa94772' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '2b37de1f-9ce9-4f66-95ec-04e19aa94772' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'c92fa827-a119-439e-8708-b8e98e599be1' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c92fa827-a119-439e-8708-b8e98e599be1' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c92fa827-a119-439e-8708-b8e98e599be1' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '6c9c4549-657d-4344-b17b-b06e12232b05' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '6c9c4549-657d-4344-b17b-b06e12232b05' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '6c9c4549-657d-4344-b17b-b06e12232b05' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'd672801a-df60-4a49-b6cd-d0ddf1b52242' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'd672801a-df60-4a49-b6cd-d0ddf1b52242' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'd672801a-df60-4a49-b6cd-d0ddf1b52242' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '87e075b9-fd68-465b-93e7-bccfb648e4c6' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '87e075b9-fd68-465b-93e7-bccfb648e4c6' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '87e075b9-fd68-465b-93e7-bccfb648e4c6' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '948dc16d-0030-42fd-8aaa-55a0fcac2d2e' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '948dc16d-0030-42fd-8aaa-55a0fcac2d2e' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '948dc16d-0030-42fd-8aaa-55a0fcac2d2e' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '1ed30c3f-777d-4165-a9c6-574091d56bc4' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '1ed30c3f-777d-4165-a9c6-574091d56bc4' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '1ed30c3f-777d-4165-a9c6-574091d56bc4' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '5870cd62-0543-433d-a876-eb7f11fbf3b3' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5870cd62-0543-433d-a876-eb7f11fbf3b3' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5870cd62-0543-433d-a876-eb7f11fbf3b3' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'e049d862-be52-422f-bdb4-e032ff9af567' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'e049d862-be52-422f-bdb4-e032ff9af567' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'e049d862-be52-422f-bdb4-e032ff9af567' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'dacd8af2-fd09-4a75-9f19-b320b9f5668b' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'dacd8af2-fd09-4a75-9f19-b320b9f5668b' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'dacd8af2-fd09-4a75-9f19-b320b9f5668b' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '2efec7f7-243c-4279-80d8-1732aedbdffe' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '2efec7f7-243c-4279-80d8-1732aedbdffe' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '2efec7f7-243c-4279-80d8-1732aedbdffe' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'a87df633-54be-4e0e-be8b-20a2e80122e8' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'a87df633-54be-4e0e-be8b-20a2e80122e8' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'a87df633-54be-4e0e-be8b-20a2e80122e8' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '5799cd4d-95da-4f0a-854c-73215564e0ed' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5799cd4d-95da-4f0a-854c-73215564e0ed' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5799cd4d-95da-4f0a-854c-73215564e0ed' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '84e2c7b2-0343-455c-bb2a-739b7d0936d3' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '84e2c7b2-0343-455c-bb2a-739b7d0936d3' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '84e2c7b2-0343-455c-bb2a-739b7d0936d3' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '526d912d-88d8-4be5-9db5-fb8e576e604b' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '526d912d-88d8-4be5-9db5-fb8e576e604b' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '526d912d-88d8-4be5-9db5-fb8e576e604b' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'c8eaa320-baea-46f4-bf19-89512ad03a52' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c8eaa320-baea-46f4-bf19-89512ad03a52' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c8eaa320-baea-46f4-bf19-89512ad03a52' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '8e0e7545-2cfe-4435-8d48-54ecc2302911' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '8e0e7545-2cfe-4435-8d48-54ecc2302911' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '8e0e7545-2cfe-4435-8d48-54ecc2302911' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'b58e0c41-1c87-43a1-a939-421220018ce8' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'b58e0c41-1c87-43a1-a939-421220018ce8' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'b58e0c41-1c87-43a1-a939-421220018ce8' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '2582b640-af1d-41cf-a406-3573a9d24ad5' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '2582b640-af1d-41cf-a406-3573a9d24ad5' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '2582b640-af1d-41cf-a406-3573a9d24ad5' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'c15900f4-d02e-4094-a893-208a392b6bb5' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c15900f4-d02e-4094-a893-208a392b6bb5' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c15900f4-d02e-4094-a893-208a392b6bb5' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '66b0d92f-1542-4d1e-8864-ff35b1d1f361' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '66b0d92f-1542-4d1e-8864-ff35b1d1f361' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '66b0d92f-1542-4d1e-8864-ff35b1d1f361' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '108806a0-6f47-4254-a2b9-5ca23e844e9a' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '108806a0-6f47-4254-a2b9-5ca23e844e9a' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '108806a0-6f47-4254-a2b9-5ca23e844e9a' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'b76fc1d2-eb7a-450e-be56-2ae714762b73' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'b76fc1d2-eb7a-450e-be56-2ae714762b73' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'b76fc1d2-eb7a-450e-be56-2ae714762b73' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '4c029267-7445-4b42-b9c3-2d0ed5ef5c18' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '4c029267-7445-4b42-b9c3-2d0ed5ef5c18' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '4c029267-7445-4b42-b9c3-2d0ed5ef5c18' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '75b83c84-5180-4ad6-acf9-4e864d2525da' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '75b83c84-5180-4ad6-acf9-4e864d2525da' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '75b83c84-5180-4ad6-acf9-4e864d2525da' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '3f9d8667-fa22-4a4f-ba47-b663e7e316dd' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '3f9d8667-fa22-4a4f-ba47-b663e7e316dd' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '3f9d8667-fa22-4a4f-ba47-b663e7e316dd' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '4a503cdd-3479-485d-b0da-cc1f2f7a3bf9' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '4a503cdd-3479-485d-b0da-cc1f2f7a3bf9' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '4a503cdd-3479-485d-b0da-cc1f2f7a3bf9' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'cd13cd2a-d850-42a4-87a5-6015fbc0ac0a' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'cd13cd2a-d850-42a4-87a5-6015fbc0ac0a' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'cd13cd2a-d850-42a4-87a5-6015fbc0ac0a' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '5f865dc4-8531-4c3c-913c-9b4f19312493' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5f865dc4-8531-4c3c-913c-9b4f19312493' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '5f865dc4-8531-4c3c-913c-9b4f19312493' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '061923d1-741b-426c-8de9-a856247f96ed' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '061923d1-741b-426c-8de9-a856247f96ed' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '061923d1-741b-426c-8de9-a856247f96ed' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '639401ff-900a-45fa-b579-c202826e21d5' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '639401ff-900a-45fa-b579-c202826e21d5' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '639401ff-900a-45fa-b579-c202826e21d5' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'badac236-7af1-4c6f-b943-64af4b6f1a7a' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'badac236-7af1-4c6f-b943-64af4b6f1a7a' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'badac236-7af1-4c6f-b943-64af4b6f1a7a' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'c0937f3f-bbec-4947-876b-2f1f3b2e2999' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c0937f3f-bbec-4947-876b-2f1f3b2e2999' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'c0937f3f-bbec-4947-876b-2f1f3b2e2999' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '1d919d3a-7caa-4e6d-af3a-fe55a636b606' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '1d919d3a-7caa-4e6d-af3a-fe55a636b606' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '1d919d3a-7caa-4e6d-af3a-fe55a636b606' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '881af79e-4131-4ef3-b215-2aa9a378bc42' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '881af79e-4131-4ef3-b215-2aa9a378bc42' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '881af79e-4131-4ef3-b215-2aa9a378bc42' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'e9ab8b06-37fa-4ccd-8ef4-270f35639e4a' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'e9ab8b06-37fa-4ccd-8ef4-270f35639e4a' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'e9ab8b06-37fa-4ccd-8ef4-270f35639e4a' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '709d0397-a3e5-4cbd-9503-7e14fc2375df' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '709d0397-a3e5-4cbd-9503-7e14fc2375df' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '709d0397-a3e5-4cbd-9503-7e14fc2375df' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'f3637634-1f7a-47b7-b1f8-26dece24846d' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'f3637634-1f7a-47b7-b1f8-26dece24846d' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'f3637634-1f7a-47b7-b1f8-26dece24846d' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '16f32dc3-235a-4d73-bed7-3c0c8bc347e5' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '16f32dc3-235a-4d73-bed7-3c0c8bc347e5' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '16f32dc3-235a-4d73-bed7-3c0c8bc347e5' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '9adfda12-7ddb-4978-bd2d-8a594a4a365c' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '9adfda12-7ddb-4978-bd2d-8a594a4a365c' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '9adfda12-7ddb-4978-bd2d-8a594a4a365c' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = '7665a1ec-af9f-4675-a31d-cbddbb21e679' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '7665a1ec-af9f-4675-a31d-cbddbb21e679' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = '7665a1ec-af9f-4675-a31d-cbddbb21e679' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND "Order"."couponId" = 'e89c2ef2-9af4-4f9b-a6af-14438f641692' AND "Order"."couponReleased" = false;

SELECT sum("discountAmount") AS "sum" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'e89c2ef2-9af4-4f9b-a6af-14438f641692' AND "Order"."couponReleased" = false;

SELECT count(*) AS "count" FROM "Orders" AS "Order" WHERE "Order"."couponId" = 'e89c2ef2-9af4-4f9b-a6af-14438f641692' AND "Order"."couponReleased" = false AND "Order"."status" = 'picked_up';

SELECT
      COALESCE(SUM(quantity), 0)::int AS "rescuedPackages",
      COALESCE(SUM(GREATEST(COALESCE("originalTotal", "totalPrice") - "finalPrice", 0)), 0) AS "totalSaved"
      FROM "Orders" WHERE "userId" = '9be973ab-62e1-438f-bd18-a69b8fb5af69' AND status = 'picked_up'
      AND "paymentStatus" IN ('paid', 'unpaid')