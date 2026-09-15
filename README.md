# Mall

Flutter property-management app with two account views:

- **Tenant**: browsing, bookings, leases, invoices, payments and profile.
- **Manager**: shared by Owner, Manager, Admin and SuperAdmin accounts; properties, units, tenancies, money and administration.

The server's account role selects the view at sign-in and restoration. There is no view switch or embedded test credential. API authorization controls what each account can access.

## Running

```bash
flutter pub get
flutter run
# Optional environment override:
flutter run --dart-define=API_BASE_URL=https://your-api-host
```

The default API is `https://property-manager-api.transfa.org/v1/api`.
Production repositories call only operations defined in `api.md`. There is no mock switch, seeded application data or demo login. Unsupported features return an unavailable result locally without HTTP requests; a failed API request shows an error; an empty API result shows an empty state.

Some screens need capabilities the API does not provide. See [backend_requirement.md](backend_requirement.md) for the current capability gaps. The app does not invent report totals, booking quotes or booking confirmations to fill those gaps.

## Validation

```bash
flutter analyze --no-pub
flutter test --no-pub
```

Offline tests use fixtures under `test/support/` through explicit repository overrides. These fixtures are not imported by the application. `api_only_test.dart` checks production wiring, account roles, restoration and missing-endpoint behavior; `router_test.dart` checks view boundaries.

The opt-in live probe accepts `PROBE_PHONE` and `PROBE_PASSWORD` build defines. Supply credentials locally; do not commit them. It signs in and reads data without creating properties, bookings or payments.

## Layout

- `lib/modules/`: screens and controllers
- `lib/navigation/`: tenant and manager navigation (existing owner route names are retained for compatibility)
- `lib/services/remote/`: API client and HTTP repositories
- `lib/services/models/`: API mappings
- `test/support/`: offline fixtures only

Android and iOS are the primary targets. Desktop and web support development. Mobile tokens use secure storage; desktop/web use shared preferences. Google Play updates and biometric unlock are available on supported platforms.
