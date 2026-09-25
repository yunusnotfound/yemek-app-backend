# Public image cache deployment — 25 September 2026

## Change

`src/app.js` now serves public `/uploads` files before credentialed API CORS and
API rate limiting. Successful UUID v4 images receive
`public, max-age=31536000, immutable`; versioned demo catalog files receive
`public, max-age=604800`; other existing files receive a one-day public TTL.
Missing files, directories, invalid ranges and unsupported methods receive
`no-store`. Public CORS, CORP, `nosniff` and sandbox CSP are retained. API CORS
and rate limits remain unchanged.

The upload format, storage volume, database and image URLs were not changed.

## Validation

The database-free production middleware suites `tests/uploads-cache.test.js`
and `tests/catalog-rate-limit.test.js` passed: **2 suites, 27 tests**. These cover
cross-origin image access, immutable and bounded TTLs, HEAD/304 validators,
404/405/416 cache behavior, more than 100 image reads without consuming the API
budget, generic missing-file responses without `ENOENT` or absolute storage
paths, and the existing API limits. The final 404 fix passed the same 27 tests.
Jest's database global setup was omitted
only for this targeted run. `git diff --check` passed.

## Production deployment

The deployment used SSH as `deploy` and the existing `~/bitir-yemek` checkout.
Only `src/app.js` was copied; **no git pull** was performed because the server's
checkout was at a different revision. The working tree was clean and the
original file hash was verified before the update.

- Original SHA-256: `f34d6a344a067a9543c0276b14d5593ad422b940b65063b87290ef62a03359d3`
- Final deployed SHA-256: `6603f152d1a03fe510d9beb70595e4f687cd8d646edecd53a4e2b184a393c77c`
- File backup: `/home/deploy/deploy-backups/cdn-20260925T131511Z/app.js`
- Previous running image retained as `bitir-yemek-app:before-cdn-20260925T131511Z`
- Final deployed image: `sha256:a2000a3f51f62be13be53b51be7bdd4aa9bf416423fb3d5807e79245302745ed`

`docker compose build app` followed by
`docker compose up -d --no-build --no-deps app` rebuilt and replaced only the
application container. Database, Redis, web and Caddy were not restarted by
this deployment.

At **13:16 UTC**, the app container was `running healthy`; both the internal
health endpoint and `https://api.bitirgitsin.com/api/health` returned `200`, with
database and Redis connected. Public HTTP checks confirmed:

| Request | Status | Cache-Control | RateLimit headers |
| --- | --- | --- | --- |
| `/uploads/demo-catalog-v1/firin-pastane.png` | 200 | `public, max-age=604800` | absent |
| `/uploads/30885ea2-91c8-4147-a18f-bef16b93f16e.jpg` | 200 | `public, max-age=31536000, immutable` | absent |
| `/uploads/cdn-missing-verification-20260925.png` | 404 | `no-store` | absent |

These checks reached Caddy before Cloudflare DNS activation. Cloudflare setup
and edge-cache verification are separate deployment work.

### Missing-file response follow-up

A review identified that the static middleware's raw 404 error could include
an absolute filesystem path. The upload-scoped handler now returns only
`{"success":false,"message":"Görsel bulunamadı"}` for 404 errors while retaining
`no-store`. No image URL or cache lifetime changed.

The follow-up deployment verified the preceding deployed file hash
`bce0d8f6fbbf6f1a1a9b41dbbe1a9c6fc140bd9d70f1c1f9573dea8675798624`, backed it up
at `/home/deploy/deploy-backups/cdn-20260925T132327Z/app.js`, and preserved the
running image as `bitir-yemek-app:before-cdn-20260925T132327Z`. Only the app
container was rebuilt and replaced. Internal health and generic-404 checks
passed; the container was `running healthy` afterward.

At **13:24 UTC**, Cloudflare's public DNS resolvers returned `104.21.22.6` and
`172.67.201.174` for the API. Because the local system resolver still retained
the old origin address, edge checks used
`curl --resolve api.bitirgitsin.com:443:104.21.22.6` with the original HTTPS
hostname and certificate validation:

- Health returned `200`, with database and Redis connected.
- A missing image returned generic `404`, `Cache-Control: no-store`, and
  `CF-Cache-Status: BYPASS`, with no filesystem path in its body.
- Two consecutive requests for `demo-catalog-v1/firin-pastane.png` returned
  `CF-Cache-Status: MISS` then `HIT` from the Istanbul POP (`CF-Ray` suffix
  `IST`). The origin TTL and absent RateLimit headers were preserved.

The server's `src/app.js` remains a tracked local modification. Preserve this
patch or reconcile it with the matching repository commit before a future
`git pull --ff-only` deployment.

## Rollback

Run in `~/bitir-yemek` on the server if needed:

```sh
cp -p /home/deploy/deploy-backups/cdn-20260925T131511Z/app.js src/app.js
docker image tag bitir-yemek-app:before-cdn-20260925T131511Z bitir-yemek-app:latest
docker compose up -d --no-build --no-deps app
curl -fsS https://api.bitirgitsin.com/api/health
```

## Remaining image-size opportunity

Public business-image checks found six demo catalog PNGs of approximately
2.17–2.76 MB each; the real uploaded JPEG sampled was 14,572 bytes. CDN caching
reduces origin traffic and repeat transfer latency, but the large demo images
still require downloading their full bytes. Publishing compressed WebP copies
under new versioned URLs can further reduce first-load data usage. That image
conversion and any catalog URL updates are outside this backend deployment.
