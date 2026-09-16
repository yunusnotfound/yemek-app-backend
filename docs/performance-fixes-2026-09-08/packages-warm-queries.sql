SELECT count("SurprisePackage"."id") AS "count" FROM "SurprisePackages" AS "SurprisePackage" INNER JOIN "Businesses" AS "business" ON "SurprisePackage"."businessId" = "business"."id" AND ("business"."deletedAt" IS NULL AND ("business"."isActive" = true AND "business"."isApproved" = true AND "business"."isSuspended" = false AND "business"."latitude" BETWEEN '40.55084441250449' AND '41.44915558749551' AND "business"."longitude" BETWEEN '28.404863010533234' AND '29.595136989466766')) LEFT OUTER JOIN "Categories" AS "business->category" ON "business"."categoryId" = "business->category"."id" WHERE ("SurprisePackage"."deletedAt" IS NULL AND (("SurprisePackage"."isActive" = true AND "SurprisePackage"."isSuspended" = false AND "SurprisePackage"."remainingQuantity" > 0 AND "SurprisePackage"."pickupDate" >= '2026-09-08') AND (
  6371 * acos(
    LEAST(1, GREATEST(-1,
      cos(radians(41)) * cos(radians("business"."latitude"))
        * cos(radians("business"."longitude") - radians(29))
      + sin(radians(41)) * sin(radians("business"."latitude"))
    ))
  )
) <= 50));

SELECT "SurprisePackage"."id", "SurprisePackage"."businessId", "SurprisePackage"."title", "SurprisePackage"."description", "SurprisePackage"."originalPrice", "SurprisePackage"."discountedPrice", "SurprisePackage"."quantity", "SurprisePackage"."remainingQuantity", "SurprisePackage"."pickupStart", "SurprisePackage"."pickupEnd", "SurprisePackage"."pickupDate", "SurprisePackage"."imageUrl", "SurprisePackage"."isSuspended", "SurprisePackage"."isActive", "SurprisePackage"."isRecurring", "SurprisePackage"."recurringDays", "SurprisePackage"."createdAt", "SurprisePackage"."updatedAt", "SurprisePackage"."deletedAt", "business"."id" AS "business.id", "business"."name" AS "business.name", "business"."address" AS "business.address", "business"."city" AS "business.city", "business"."district" AS "business.district", "business"."latitude" AS "business.latitude", "business"."longitude" AS "business.longitude", "business"."imageUrl" AS "business.imageUrl", "business"."rating" AS "business.rating", (
  6371 * acos(
    LEAST(1, GREATEST(-1,
      cos(radians(41)) * cos(radians("business"."latitude"))
        * cos(radians("business"."longitude") - radians(29))
      + sin(radians(41)) * sin(radians("business"."latitude"))
    ))
  )
) AS "business.distance", "business->category"."id" AS "business.category.id", "business->category"."name" AS "business.category.name", "business->category"."slug" AS "business.category.slug" FROM "SurprisePackages" AS "SurprisePackage" INNER JOIN "Businesses" AS "business" ON "SurprisePackage"."businessId" = "business"."id" AND ("business"."deletedAt" IS NULL AND ("business"."isActive" = true AND "business"."isApproved" = true AND "business"."isSuspended" = false AND "business"."latitude" BETWEEN '40.55084441250449' AND '41.44915558749551' AND "business"."longitude" BETWEEN '28.404863010533234' AND '29.595136989466766')) LEFT OUTER JOIN "Categories" AS "business->category" ON "business"."categoryId" = "business->category"."id" WHERE ("SurprisePackage"."deletedAt" IS NULL AND (("SurprisePackage"."isActive" = true AND "SurprisePackage"."isSuspended" = false AND "SurprisePackage"."remainingQuantity" > 0 AND "SurprisePackage"."pickupDate" >= '2026-09-08') AND (
  6371 * acos(
    LEAST(1, GREATEST(-1,
      cos(radians(41)) * cos(radians("business"."latitude"))
        * cos(radians("business"."longitude") - radians(29))
      + sin(radians(41)) * sin(radians("business"."latitude"))
    ))
  )
) <= 50)) ORDER BY (
  6371 * acos(
    LEAST(1, GREATEST(-1,
      cos(radians(41)) * cos(radians("business"."latitude"))
        * cos(radians("business"."longitude") - radians(29))
      + sin(radians(41)) * sin(radians("business"."latitude"))
    ))
  )
) ASC, "SurprisePackage"."pickupDate" ASC LIMIT 10 OFFSET 0;