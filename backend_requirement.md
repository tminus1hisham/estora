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

## Validation

The contract regression tests compare every endpoint declaration with `api.md`.
Offline tests check that unsupported operations make no network requests.
The optional live probe requires locally supplied `PROBE_PHONE` and
`PROBE_PASSWORD`; it is skipped without them.
