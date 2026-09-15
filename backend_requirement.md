# Backend requirements

What the app needs that `api.md` (Property Manager API v1) does not serve yet.

All app repositories now use the live API. Missing routes return errors; no
screen falls back to an in-memory server or fabricated records.

Live verification on 2026-09-15 confirmed that Manager, Admin and Tenant login
returns the expected account role. Manager and Admin can list properties.
`/reports/owner-portfolio`, `/reports/tenant-dashboard` and `/tenants/me` return
404. The Tenant account receives 403 from `/auth/get/account` and the property
list route; backend permissions must be corrected for those tenant features.
Login already includes the account, so initial tenant sign-in does not depend
on `/auth/get/account`. Session restoration still requires that endpoint;
tenants must sign in again until access is corrected. The refresh endpoint
also rejected the valid tenant token pair with `Invalid tokens`.

Owner, Manager, Admin and SuperAdmin share the manager view. Report endpoints
must scope their responses to the authenticated account's actual permissions.

Paths are relative to `/v1/api`. All routes are bearer-authenticated.

---

## 1. Leases — blocks the whole tenancy flow

`Lease` is already defined in the contract; only the routes are missing.

| Method | Path | Returns |
|---|---|---|
| GET | `/leases?status=&page=` | `Lease[]` for the signed-in tenant |
| GET | `/leases/{id}` | `Lease` |
| GET | `/leases/{id}/agreement` | the agreement text/PDF url + whether each party has signed |
| POST | `/leases/{id}/signatures` | records the tenant's signature, returns the updated `Lease` |

The signing route must be idempotent on `Idempotency-Key` — a tenant signs once.

## 2. Bookings — the unit is reserved but the app cannot read it back

`POST /payments/book/unit` and `/payments/confirm/booked/unit` exist. What is
missing is everything after the write.

| Method | Path | Returns |
|---|---|---|
| GET | `/bookings?status=&page=` | `Booking[]` for the signed-in tenant |
| GET | `/bookings/{id}` | `Booking` |
| POST | `/bookings/{id}/cancel` | the cancelled `Booking` |
| GET | `/bookings/quote/{unitId}` | booking fee, deposit, first rent, total — priced **server-side**, before committing |
| PUT | `/bookings/{id}/requirements/{requirementId}` | marks a KYC/document requirement satisfied |

The quote matters most: the app must never compute what a tenant is about to pay.

## 3. Receipts

| Method | Path | Returns |
|---|---|---|
| GET | `/receipts?page=` | `Receipt[]` |
| GET | `/receipts/{id}` | `Receipt` |
| GET | `/receipts/by-payment/{paymentId}` | the receipt for a settled payment |

A receipt needs its own number, the payment it settles, the invoice lines it
covers, and any platform fee **as its own line, not netted off**.

## 4. Documents

| Method | Path | Returns |
|---|---|---|
| GET | `/documents?type=&page=` | document metadata (name, type, size, uploaded date) |
| GET | `/documents/{id}/download-url` | a short-lived signed URL |
| POST | `/documents` | multipart upload, returns the created document |

Download must be a signed URL, not the bytes — the app streams to the OS viewer.

## 5. Notifications

| Method | Path | Returns |
|---|---|---|
| GET | `/notifications?page=` | notifications, newest first |
| GET | `/notifications/unread-count` | `{ "count": n }` |
| POST | `/notifications/{id}/read` | — |
| POST | `/notifications/read-all` | — |
| GET / PUT | `/notifications/preferences` | which channels (push, SMS, email) are on |

## 6. The signed-in tenant

`/auth/get/account` returns the *user*, not the tenant record. `Tenant` is
already defined in the contract; the app needs it addressable as "me".

| Method | Path | Returns |
|---|---|---|
| GET | `/tenants/me` | the `Tenant` for the signed-in user |
| PUT | `/tenants/me/profile` | updates business name, KRA PIN, emergency contact |

Without this, `/payments/get/invoices/{tenantId}` cannot be called at all: the
app has a user id and no way to turn it into a tenant id.

## 7. Tenant dashboard

| Method | Path | Returns |
|---|---|---|
| GET | `/reports/tenant-dashboard` | balance due, next due date, active lease, recent payments, unread count |

One call, computed server-side. The app must not add up invoices itself.

## 8. Owner reporting — the entire owner tier

| Method | Path | Returns |
|---|---|---|
| GET | `/owners/me` | the owner record for the signed-in user |
| GET | `/reports/owner-portfolio` | per-property occupancy, rent roll total, arrears |
| GET | `/reports/owner-property/{propertyId}` | one property's performance |
| GET | `/reports/owner-ledger` | money in vs money owed out |
| GET | `/properties/{propertyId}/rent-roll` | unit, tenant, rent, paid-to date |
| GET | `/owners/me/tenancies?propertyId=` | active tenancies across the portfolio |
| GET | `/owners/me/tenancies/{leaseId}` | one tenancy in full |
| GET/PUT | `/properties/{propertyId}/rate` | the rate per m² the property prices from |
| GET | `/properties/{propertyId}/rate/impact` | what a proposed rate change would do to each unit, **before** applying it |
| PUT | `/units/{unitId}/rent` | override one unit's rent, or clear the override |

Rate-per-m² is how an owner prices a property: set the rate, every unit's rent
follows from its area unless individually overridden. `Property` and
`PropertyUnit` currently carry no rate field and no override flag, so both need
adding alongside the routes.

## 9. Payment status — small but blocking

`POST /payments/create/payment/request` starts an M-Pesa payment. There is no
way to ask how it ended.

| Method | Path | Returns |
|---|---|---|
| GET | `/payments/{id}` | the payment and its current state |
| GET | `/payments?page=` | the tenant's payment history |

The handset must never decide a payment succeeded. The app polls this every 3s
for up to 3 minutes; without it, a tenant who pays sees nothing change.

---

## Smaller gaps

- **Unit pricing history** — `GET /units/{id}/pricing`. Effective-dated rents, so
  a tenant sees a scheduled increase before committing.
- **Unit types and floors** — `GET /properties/{id}/unit-types`,
  `GET /buildings/{id}/floors`. Currently the unit filters cannot be populated.
- **Property fields** — `Property` has no short code, no street address, no
  county and no owner id. The app falls back to the name and leaves the rest blank.
- **Sign-in by OTP** — the only code flow is `/auth/enable/two/factor`, which
  requires an existing session. There is no way to start one with phone + code.
- **Sign-out** — no route. The app drops the token locally; a real revocation
  endpoint would be better.
- **No pagination anywhere.** Every list route returns the whole array. This is
  survivable now and will not be at a few thousand invoices.

## Behaviour worth changing

- **`POST /auth/register` is behind `[Authorize]` — nobody can create an
  account.** The deployed route answers `401` with `WWW-Authenticate: Bearer`
  and an empty body before it ever reads the payload, so registration is closed
  to the only people who need it. `api.md` documents `200` and `400` for this
  operation and no `401`, so the gate is the deployment, not the contract.
  `/auth/confirm/email` and `/auth/confirm/phonenumber` are gated the same way
  and have the same problem: they are how an account is verified *before* it
  can sign in. The rest of the pre-session routes are open and behave —
  `/auth/login`, `/auth/forgot/password`, `/auth/reset/password` and
  `/auth/verify/two/factor` all reach their handler and answer `400`.

  Reproduce:

  ```
  curl -i -X POST https://property-manager-api.transfa.org/v1/api/auth/register     -H 'Content-Type: application/json' -d '{}'
  ```

- **A failed sign-in returns `400`, not `401`,** with
  `{"success": false, "errors": ["User not found"]}`. Two different shapes carry
  errors elsewhere (`{"message": ...}` and ASP.NET's
  `{"title": ..., "errors": {...}}`); the client now reads all three, but one
  consistent error envelope would be better.
- **`/auth/login` returns no token expiry.** The app assumes one hour and
  refreshes on any 401. An `expiresAt` would remove the guess.
- **`/auth/login` returns a fully-populated empty `user` object on failure**
  (zeroed ids, epoch dates) rather than `null`, which is easy to mistake for a
  real account.
- **Two route paths are missing a separator:**
  `/properties/get/all/units/in/property{propertyId}` and
  `.../in/block{blockId}`. The app matches them as-is; worth fixing at some
  point, with the client updated in the same release.

---

## How to verify

`test/live_api_probe_test.dart` drives the real client against the live server —
sign-in, account, properties, blocks, units, invoices, M-Pesa, bank payments,
roles and claims:

```
flutter test test/live_api_probe_test.dart \
  --dart-define=PROBE_PHONE=2547... --dart-define=PROBE_PASSWORD=...
```

It is skipped without those, so a plain `flutter test` stays offline. It only
reads; the sign-in is the sole write.
