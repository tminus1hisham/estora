# API capability gaps

`api.md` is the source of truth for supported paths, HTTP methods and payloads.
The client must use this API as published. This file does not propose routes or
require the backend to implement the app?s original screen design.

## Unsupported capabilities

The current contract does not expose operations for:

- Lease lists, agreements or signatures.
- Booking quotes, retrieval, cancellation or document requirements.
- Tenant payment history or payment-status polling.
- Receipts, document storage or notifications and their preferences.
- Extended tenant profiles or owner profiles.
- Tenant dashboards, owner portfolio/performance reports, ledgers or rent rolls.
- Repricing previews, bulk rent repricing or unit rent overrides.

These repository operations return `UnsupportedFeatureFailure` locally and
send no HTTP request. Unit types and pricing also have no published read route.
Do not add guessed paths to fill these gaps.

## Supported operations

Use the existing auth/account, property/block/unit, invoice/payment, treasury,
and role/claim operations defined in `api.md`. Preserve the published unit-list
paths, including the missing slash before the property/block path parameter.

Booking and payment requests exist, but their documented responses do not
provide the complete booking and payment-tracking models used by the screens.
A successful request must not be treated as proof of a confirmed booking or
settled payment.

## Invoices and leases are keyed on the tenant record, not the account

`GET /payments/get/invoices/{tenantId}` means `Tenant.id`, not `EstoraUsers.id`.
The two records are separate and joined on `userId`, so the account's own `id`
reads whichever tenancy happens to wear that number, or none.

The app resolves the tenant record once per session and caches it:

1. a `tenantId` the account payload names outright;
2. the record in `GET /properties/get/all/tenants` whose `userId` matches the
   account's — failing that, whose phone number does;
3. the `tenantId` on a booking from `GET /payments/get/all/bookings` made with
   the account's own number, for a token the directory is closed to.

Steps 2 and 3 are probes: a route that refuses hands the question to the next
one rather than failing the statement. An account none of them names has no
tenancy, and shows an empty statement rather than an error.

`GET /properties/get/lease/agreements` takes no parameter, so the same
resolved id narrows the leases it answers with. An account with no tenant
record — a manager, an owner — is shown the list as the server sent it.

## Token renewal happens before expiry

`POST /auth/refresh/token` is behind `[Authorize]` on the live server: a call
with no bearer answers a bodiless 401 (checked 2026-09-21). A token that has
already expired is therefore turned away at the gate before the route reads
the refresh token, and the session cannot be recovered.

The app works around this by renewing early: it reads the JWT's `exp` claim
(falling back to an assumed hour) and, when a request goes out within a
minute of it, renews first — sending the expiring token as the bearer and in
the body, as the contract's `TokenRequest` asks. A 401 on any other route
still triggers a renewal and one retry, for a clock that ran ahead.

The backend fix is to mark the refresh route `[AllowAnonymous]`, or to accept
an expired bearer on it (`ValidateLifetime = false` for that route only). Until
then, a handset that stays closed past the token's life signs in again.

## Validation

The contract regression tests compare every endpoint declaration with `api.md`.
Offline tests check that unsupported operations make no network requests.
The optional live probe requires locally supplied `PROBE_PHONE` and
`PROBE_PASSWORD`; it is skipped without them.
