import 'package:estora/core/utils/date_format.dart';
import 'mock_records.dart';
import 'mock_server.dart';

/// Renders a lease agreement from a template.
///
/// Section 28 asks for document templates with `{{tenant.name}}`-style
/// variables rather than hard-coded agreement text, and section 50 makes the
/// same point for notification copy. On the real backend these templates are
/// managed by the platform administrator (section 79) and rendered to PDF
/// server-side; this function stands in for that, and deliberately keeps the
/// substitution table explicit so the variable list matches the spec's.
///
/// The rendered text is hashed and the hash travels with the signature
/// (section 29), which is what binds a signature to the exact wording the
/// tenant read.
String renderAgreement(MockServer server, LeaseRow lease) {
  final property = server.properties[lease.propertyId]?.toDomain();
  final unit = server.units[lease.unitId];
  final tenant = server.currentTenant;
  final profile = tenant?.profile;

  final variables = <String, String>{
    'tenant.name': tenant?.displayName ?? '—',
    'tenant.business_name': profile?.legalName ?? tenant?.displayName ?? '—',
    'tenant.registration_number': profile?.registrationNumber ?? '—',
    'tenant.address': profile?.address ?? '—',
    'property.name': property?.name ?? '—',
    'property.address': property?.locationLabel ?? '—',
    'unit.unit_number': unit?.unitNumber ?? lease.unitNumber ?? '—',
    'unit.area': unit?.area == null ? '—' : '${unit!.area} ${unit.areaUnit}',
    'lease.number': lease.leaseNumber,
    'lease.start_date': AppDate.full(lease.startDate),
    'lease.end_date': AppDate.full(lease.endDate),
    'lease.monthly_rent': lease.monthlyRent.format(),
    'lease.deposit_amount': lease.depositAmount.format(),
    'lease.payment_due_day': _ordinal(lease.paymentDueDay),
    'lease.billing_frequency': lease.billingFrequency.label.toLowerCase(),
  };

  return _substitute(_template, variables);
}

String _substitute(String template, Map<String, String> variables) {
  return template.replaceAllMapped(
    RegExp(r'\{\{\s*([a-zA-Z0-9_.]+)\s*\}\}'),
    (match) => variables[match.group(1)] ?? match.group(0)!,
  );
}

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}

const String _template = '''
LEASE AGREEMENT

Agreement number {{lease.number}}

THIS LEASE is made between the landlord of {{property.name}}, {{property.address}} (the "Landlord") and {{tenant.business_name}}, registration number {{tenant.registration_number}}, of {{tenant.address}} (the "Tenant").

1. PREMISES

The Landlord lets to the Tenant, and the Tenant takes from the Landlord, Unit {{unit.unit_number}} at {{property.name}}, comprising approximately {{unit.area}} (the "Premises"), together with the right to use the common areas of the property in common with other tenants.

2. TERM

The term of this lease begins on {{lease.start_date}} and ends on {{lease.end_date}}, unless terminated earlier in accordance with clause 9.

3. RENT

The Tenant shall pay rent of {{lease.monthly_rent}} {{lease.billing_frequency}} in advance, due on the {{lease.payment_due_day}} day of each month. An invoice will be issued in advance of each due date.

4. SECURITY DEPOSIT

The Tenant has paid a security deposit of {{lease.deposit_amount}}. The deposit is held by the Landlord for the term of this lease and is refundable on expiry, less any amounts properly deducted for rent arrears, unpaid utilities or damage beyond fair wear and tear.

5. SERVICE CHARGE AND UTILITIES

The Tenant shall pay the service charge notified by the Landlord, covering security, cleaning, common area maintenance and waste management. Electricity and water consumed at the Premises are metered and billed to the Tenant.

6. USE OF PREMISES

The Tenant shall use the Premises only for the permitted use recorded in the lease terms, and shall not change that use without the Landlord's prior written consent.

7. ASSIGNMENT AND SUBLETTING

The Tenant shall not assign, sublet or part with possession of the Premises or any part of them without the Landlord's prior written consent.

8. MAINTENANCE

The Tenant shall keep the interior of the Premises in good repair. The Landlord shall maintain the structure, exterior and common areas of the property.

9. TERMINATION

Either party may terminate this lease on three months' written notice. Either party may terminate immediately for a material breach that remains unremedied thirty days after written notice of it.

10. LATE PAYMENT

Amounts outstanding beyond the grace period recorded in the lease terms attract the late payment fee recorded in those terms.

11. GOVERNING LAW

This lease is governed by the laws of Kenya.

SIGNED by the Tenant: {{tenant.name}}

By signing electronically below, the Tenant confirms that they have read and agree to be bound by this agreement in its entirety.
''';
