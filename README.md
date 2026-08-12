# Tenant Mobile Application

The tenant-facing mobile app for the commercial property management platform
specified in [context.md](context.md) — sections 3.1, 45, 77, 90 and 97.

It covers the tenant's whole journey: browse available units, book one, pay the
booking fee, submit requirements, review and sign the lease, pay the deposit,
then receive and pay recurring rent invoices and download receipts.

The property-manager web app (§4, §78) and the platform-administrator web app
(§5, §79) are separate applications and are **not** in this repository.

## Running it

```bash
flutter pub get
flutter run            # or: flutter run -d chrome
```

Android and iOS are the real targets. The app also runs on web and desktop for
development and demos — see *Platform notes* below for what differs there.

### The demo account

The app ships pointing at an in-memory mock of the platform API, so it is fully
usable with no backend.

* **Sign in** with any email and password, or with any phone number.
* **OTP**: the code is `123456`. The OTP screen says so when running against the
  mock, since there is no SMS gateway behind it.

The seeded tenant is Wanjiru Retail Ltd, with an active lease on SHOP-101 at
Sarit Mall, a settled deposit, a paid rent invoice with a receipt, and a current
rent invoice still outstanding — so every screen has something on it from the
first launch.

### Walking the full flow

To follow §94's acceptance path end to end, book a unit that is free —
**SHOP-102** — and work through: quote → pay booking fee → booking becomes
active with a 48-hour countdown → upload the required documents → pay the
deposit → lease generated → review and sign → property manager approves →
rent invoice raised → pay → receipt.

To see the failure path, pay with an M-Pesa number ending `0000`.

## Pointing it at a real backend

One constant, in [lib/core/config/app_config.dart](lib/core/config/app_config.dart):

```dart
static const DataSource dataSource = DataSource.remote;
```

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

Every repository provider in
[lib/services/providers.dart](lib/services/providers.dart) reads that constant
and returns either the mock or the HTTP implementation. No screen, controller or
widget imports an implementation directly, so nothing above the data layer
changes.

The HTTP implementations in
[lib/services/remote/](lib/services/remote/) are written against the endpoint
layout in §64 but **have not been exercised against a running server**, because
none exists yet. Expect to adjust key names in
[lib/services/models/api_mappers.dart](lib/services/models/api_mappers.dart)
when the backend is real; that file is the only place that knows the wire
format. The API contract this app expects is documented at the top of it.

## Layout

§97's mobile tree, mapped to Flutter idiom. `hooks/` has no Flutter analogue —
Riverpod providers fill that role — and is the one omission.

```
lib/
  core/          config, theme, Money, Result/Failure, formatting
  navigation/    go_router configuration and the tab shell
  components/    shared widgets
  storage/       token storage
  domain/        enums, entities, repository interfaces
  services/      mock server, HTTP client, JSON mappers, DI
  modules/       auth home properties units bookings leases
                 invoices payments documents notifications profile
```

Screens read state from controllers; controllers depend on repository
*interfaces*; only `services/mock/` and `services/remote/` know where data comes
from.

## What the mock does, and why it matters

[lib/services/mock/mock_server.dart](lib/services/mock/mock_server.dart) is
written as a *server*, not as a convenience for the UI. Fee and deposit
calculation, reference generation, availability locking, idempotency replay,
invoice totalling, payment allocation, receipt issuing and platform-fee
recording all happen behind the repository boundary.

That split is deliberate. §65 forbids the client from computing authoritative
financial amounts and §84 rule 7 puts totalling on the server. Had those rules
been implemented in a controller, swapping in the real backend would mean
deleting business logic out of the UI — and anything missed would silently
disagree with the server.

Concretely, the app never:

* computes a payable total — it renders the server's quote or invoice verbatim;
* sends an amount when creating a booking (the body is `{unitId}`) or paying;
* decides a payment succeeded — it polls until the server reports a terminal
  status (§39);
* re-derives a booking's or lease's figures from the unit's current price
  (§21, §55);
* activates a lease (§30).

## Tests

```bash
flutter test
```

66 tests. Most run against the mock server directly, since the rules they check
are §93's server rules — availability and double-booking, idempotent replay of
booking and payment keys, expiry releasing a unit without deleting the booking,
terms surviving a later price change, payment settling through to allocation and
receipt, invoice generation being idempotent, the lease signing gate and
stale-hash rejection.

[test/acceptance_test.dart](test/acceptance_test.dart) is different: it drives
the §94 path through the real widget tree, so "it builds" and "it works" are
separate claims with separate evidence. It deliberately runs at phone
proportions (420×950) rather than the 800×600 default test surface — the first
run at phone width surfaced three real layout overflows that a wide viewport
hides.

## Platform notes

`flutter devices` in this environment reports only Windows, Chrome and Edge, so
verification was done on Chrome at a mobile viewport plus `flutter build apk`.
Two things differ away from Android and iOS:

* **Token storage** falls back to `shared_preferences`, which is *not* secure.
  [lib/storage/token_store_factory.dart](lib/storage/token_store_factory.dart)
  makes sure real devices always get keychain/keystore storage.
* **Biometric unlock** is hidden, since there is no equivalent.

`flutter_secure_storage` is held below 11.0.0 on purpose: that release requires
`compileSdk 37`, which is newer than this Flutter SDK's own default of 36, so the
Android build fails unless every developer installs an extra platform. 10.3.x has
the same API surface this app uses.

## Not built

Everything the spec assigns to Phase 2 and 3 (§87, §88) — utilities, meters,
maintenance, parking, access control, tenant staff, sales. Per §96.17 these are
not stubbed; the module layout simply leaves room for them.
