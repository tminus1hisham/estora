# Estora & Commercial Property Management Platform

## 1. Project Overview

The system is a multi-property commercial real-estate management platform designed to manage malls, commercial buildings, retail spaces and eventually other types of leasable properties.

The initial focus is:

1. Estora/property creation and configuration.
2. Unit/space management.
3. Unit availability and pricing.
4. Leasing/booking.
5. Tenant onboarding.
6. Deposits and booking fees.
7. Lease agreement generation and signing.
8. Recurring rent billing.
9. Invoice management.
10. Payment collection and reconciliation.
11. Platform/service fees.
12. Tenant mobile application.
13. Property manager web application.
14. Platform administrator web application.

The architecture must be designed so that future modules can be added without restructuring the core system.

Future capabilities may include:

- Electricity meter management.
- Water meter management.
- Internet/Wi-Fi management.
- Smart locks/access control.
- Parking management.
- Maintenance requests.
- Service charges.
- Utility billing.
- Property sales.
- Facility management.
- Visitor management.
- Security management.
- Tenant communication.
- Advertising/marketing spaces.
- Reports and analytics.
- Multiple property owners.
- Multiple currencies.
- Multiple countries.

---

# 2. Core Product Concept

The system should follow this hierarchy:

```
Platform
  |
  +-- Property Owner
  |
  +-- Property / Estora
        |
        +-- Buildings / Wings / Floors
              |
              +-- Units
                    |
                    +-- Booking
                    |
                    +-- Lease
                          |
                          +-- Tenant
                          |
                          +-- Invoices
                          |
                          +-- Payments
                          |
                          +-- Documents
                          |
                          +-- Utilities
                          |
                          +-- Access Control
```

The system should not hard-code the concept of “estora” too deeply.

A better domain model is:

```
Property
```

where:

```
property.type = MALL
```

This allows the platform to later support:

- Estora
- Office Building
- Business Centre
- Warehouse
- Apartment Complex
- Retail Centre
- Mixed-Use Development

---

# 3. User Applications

The platform consists of three primary applications.

## 3.1 Tenant Mobile Application

Used by tenants.

Primary capabilities:

- Account registration/login.
- Identity/profile management.
- Browse available units.
- View unit details.
- Request/book a unit.
- Pay booking fee.
- Track booking.
- View lease agreement.
- Sign lease agreement.
- Download documents.
- View invoices.
- Pay invoices.
- View payment history.
- Download receipts.
- View outstanding balances.
- View lease information.
- View unit information.
- Receive notifications.
- Submit maintenance requests.
- View utility usage/bills in future.
- Manage authorized occupants/staff in future.
- Manage access devices in future.

---

# 4. Property Manager Web Application

Property managers operate individual properties.

Capabilities:

### Property Management

- Create property.
- Edit property.
- Configure property.
- Configure property branding.
- Configure payment details.
- Configure billing rules.
- Configure lease rules.

### Unit Management

- Create units.
- Create batches of units.
- Configure unit sizes.
- Configure pricing.
- Configure deposits.
- Configure booking fees.
- Configure requirements.
- Change availability.
- Mark units unavailable.
- View occupancy.

### Leasing

- View bookings.
- Approve/reject bookings.
- View prospective tenants.
- Manage lease applications.
- Generate agreements.
- Track signatures.
- Activate leases.
- Terminate leases.
- Renew leases.

### Tenant Management

- View tenants.
- View tenant profiles.
- View tenant leases.
- View invoices.
- View payments.
- View documents.
- Suspend/block tenant where appropriate.

### Billing

- Generate invoices.
- View invoices.
- Track overdue invoices.
- Record payments.
- Reconcile payments.
- Issue receipts.
- Configure billing dates.

### Reporting

- Occupancy.
- Revenue.
- Outstanding balances.
- Collections.
- Lease expirations.
- Available units.
- Tenant statistics.

---

# 5. Platform Administrator Web Application

The platform administrator controls the SaaS/platform itself.

Capabilities:

- Manage property managers.
- Manage organizations.
- Manage properties.
- Configure platform fees.
- Configure payment providers.
- Manage system-wide settings.
- Manage subscription plans in future.
- Manage users.
- Manage roles.
- Manage permissions.
- View platform-wide transactions.
- View platform revenue.
- View platform service fees.
- Audit activity.
- Manage system templates.
- Manage notification templates.
- Manage document templates.

The platform administrator should not need to manually manage individual tenant operations unless they have elevated permissions.

---

# 6. Multi-Tenant Architecture

The system should be designed as a multi-tenant SaaS.

Recommended hierarchy:

```
Platform
    |
    +-- Organization
          |
          +-- Property
                |
                +-- Building
                      |
                      +-- Floor
                            |
                            +-- Unit
```

An organization represents the business/property-management company using the platform.

Example:

```
Organization:
ABC Property Management Ltd

Properties:
- Sarit Estora
- ABC Business Centre
- XYZ Retail Centre
```

Users should belong to organizations.

A user may have different roles within an organization.

---

# 7. Core Entities

The initial backend domain should include at least the following entities.

```
Organization
User
Role
Permission
Property
PropertyConfiguration
Building
Floor
Unit
UnitType
UnitPricing
UnitRequirement
UnitAvailability
Tenant
TenantProfile
Booking
BookingPayment
Lease
LeaseTerm
LeaseDocument
LeaseSignature
Invoice
InvoiceLine
Payment
PaymentAllocation
Receipt
Fee
FeeConfiguration
Notification
Document
AuditLog
```

Future entities:

```
Meter
MeterReading
Utility
UtilityBill
MaintenanceRequest
AccessDevice
ParkingSpace
ParkingAllocation
ServiceCharge
PropertyOwner
PropertyOwnership
Sale
SaleAgreement
```

---

# 8. Organization

Represents a company using the platform.

### Fields

```
id
name
legal_name
registration_number
tax_number
email
phone
address
country
currency
timezone
logo
status
created_at
updated_at
```

### Status

```
ACTIVE
SUSPENDED
INACTIVE
```

---

# 9. User

Represents anyone who can authenticate into the system.

A user can be:

```
PLATFORM_ADMIN
ORGANIZATION_ADMIN
PROPERTY_MANAGER
PROPERTY_STAFF
TENANT
```

### Fields

```
id
organization_id
first_name
last_name
email
phone
password_hash
status
last_login_at
created_at
updated_at
```

Authentication should support:

- Email/password.
- Phone/OTP.
- Refresh tokens.
- Password reset.
- Email verification.
- Phone verification.

---

# 10. Role and Permission System

Do not hard-code authorization checks directly into controllers.

Use RBAC.

Example permissions:

```
property.create
property.read
property.update
property.delete

unit.create
unit.read
unit.update
unit.delete

booking.create
booking.read
booking.approve
booking.reject
booking.cancel

lease.create
lease.read
lease.update
lease.terminate
lease.renew

invoice.create
invoice.read
invoice.cancel

payment.read
payment.record
payment.refund

tenant.read
tenant.update

report.read
settings.update
```

Permissions should be composable into roles.

---

# 11. Property

Represents a estora or commercial property.

### Fields

```
id
organization_id
name
code
property_type
description
address
city
county/state
country
latitude
longitude
total_area
total_units
status
created_at
updated_at
```

### Property Types

```
MALL
RETAIL_CENTER
OFFICE
WAREHOUSE
BUSINESS_CENTER
MIXED_USE
OTHER
```

### Status

```
ACTIVE
INACTIVE
UNDER_CONSTRUCTION
ARCHIVED
```

---

# 12. Property Configuration

Property-level business rules should be configurable.

Example:

```
default_currency
default_booking_fee
booking_expiry_hours
invoice_generation_day
invoice_due_day
payment_grace_period_days
default_lease_duration
default_deposit_months
late_payment_enabled
late_payment_fee
platform_service_fee
tax_enabled
```

Important:

A property configuration should provide defaults, but individual units/leases should be able to override them.

---

# 13. Building

A property may contain multiple buildings/wings.

Example:

```
Sarit Estora
    |
    +-- Main Building
    +-- East Wing
    +-- West Wing
```

### Fields

```
id
property_id
name
code
description
status
```

---

# 14. Floor

### Fields

```
id
building_id
name
floor_number
description
status
```

Example:

```
Ground Floor
First Floor
Second Floor
```

---

# 15. Unit

A unit represents a physical leasable space.

Example:

```
Unit A01
Unit A02
Unit B01
Shop 102
Office 4B
```

### Fields

```
id
property_id
building_id
floor_id

unit_number
unit_code
name
description

unit_type_id

length
width
area
area_unit

base_rent
currency

status

created_at
updated_at
```

### Unit status

```
AVAILABLE
RESERVED
BOOKED
LEASED
UNDER_MAINTENANCE
UNAVAILABLE
BLOCKED
```

Important:

The system must distinguish between physical unit status and leasing status.

For example:

```
physical_status = AVAILABLE
leasing_status = LEASED
```

can create confusion.

Prefer deriving occupancy status from bookings and leases where possible.

---

# 16. Unit Type

Unit types allow batch creation.

Example:

```
50x100 Retail Unit
80x50 Retail Unit
20x50 Kiosk
```

### Fields

```
id
property_id
name
code
description
length
width
area
base_rent
currency
default_deposit_months
default_booking_fee
quantity
```

Example configuration:

```
Type:
50x100 Retail Unit

Quantity:
5

Rent:
KES 150,000/month

Deposit:
5 months

Booking fee:
KES 20,000

Units generated:
A01
A02
A03
A04
A05
```

---

# 17. Batch Unit Creation

The frontend should support:

```
Create Unit Batch
```

Input:

```
Unit type
Quantity
Naming prefix
Starting number
Size
Rent
Deposit requirement
Booking fee
Requirements
```

Example:

```
Prefix: SHOP
Starting number: 101
Quantity: 5
```

System generates:

```
SHOP-101
SHOP-102
SHOP-103
SHOP-104
SHOP-105
```

Each generated unit becomes an independent Unit entity.

The batch is only a creation mechanism.

Do not make the batch the actual leasing entity.

---

# 18. Unit Requirements

Requirements should be configurable.

Examples:

```
Deposit: 5 months
Business registration certificate required
National ID required
Tax certificate required
Company registration required
Signed lease agreement required
Credit/reference check required
```

Entity:

```
UnitRequirement
```

Fields:

```
id
unit_id
requirement_type
name
description
is_mandatory
value
created_at
updated_at
```

Requirement types:

```
DOCUMENT
PAYMENT
APPROVAL
CUSTOM
```

---

# 19. Pricing

Do not store all pricing logic only inside Unit.

Create pricing entities.

```
UnitPricing
```

Fields:

```
id
unit_id
billing_frequency
amount
currency
effective_from
effective_to
is_active
```

Billing frequency:

```
MONTHLY
QUARTERLY
YEARLY
CUSTOM
```

This allows future rent increases.

Example:

```
2026:
KES 150,000

2027:
KES 165,000
```

---

# 20. Tenant

A tenant represents the individual or company leasing a unit.

Tenant types:

```
INDIVIDUAL
BUSINESS
CORPORATE
```

### Tenant fields

```
id
user_id
tenant_type
display_name
status
created_at
updated_at
```

Tenant profile:

```
TenantProfile
```

Fields:

```
tenant_id
legal_name
registration_number
tax_number
national_id
passport_number
email
phone
address
contact_person
contact_person_phone
```

Sensitive identification data must be encrypted where appropriate.

---

# 21. Booking

A booking temporarily reserves a unit before a lease is finalized.

Lifecycle:

```
DRAFT
PENDING_PAYMENT
PAYMENT_PENDING
ACTIVE
EXPIRED
CANCELLED
CONVERTED_TO_LEASE
REJECTED
```

### Booking fields

```
id
unit_id
tenant_id

booking_reference

monthly_rent
deposit_amount
booking_fee

expires_at

status

created_at
updated_at
```

Important:

The booking must capture the commercial terms at the time of booking.

Do not rely entirely on the current Unit pricing.

For example:

If rent was KES 150,000 when booked and later changes to KES 170,000, the existing booking should remain KES 150,000 unless explicitly modified.

---

# 22. Booking Flow

Recommended flow:

```
Tenant selects unit
        |
        v
Create booking
        |
        v
Calculate booking fee
        |
        v
Payment required
        |
        v
Booking payment successful
        |
        v
Booking becomes ACTIVE
        |
        v
Unit becomes RESERVED
        |
        v
Booking expiry countdown begins
        |
        v
Tenant completes lease requirements
        |
        v
Deposit invoice/payment
        |
        v
Lease generated
        |
        v
Lease signed
        |
        v
Lease ACTIVE
        |
        v
Unit LEASED
```

---

# 23. Booking Expiration

Booking expiration must be automatic.

Example:

```
booking_expiry_hours = 48
```

When booking is created:

```
expires_at = created_at + 48 hours
```

A scheduled background worker checks expired bookings.

If:

```
status = ACTIVE
AND expires_at < current_time
```

then:

```
booking.status = EXPIRED
unit becomes available
```

If payment is pending after expiration:

```
payment status remains recorded
booking becomes expired
payment must be handled according to refund/credit policy
```

Do not simply delete expired bookings.

---

# 24. Booking Fee

Booking fees should be configurable.

Possible configuration:

```
FIXED
PERCENTAGE
MONTHLY_RENT_PERCENTAGE
CUSTOM
```

Example:

```
Booking fee = KES 20,000
```

or:

```
Booking fee = 10% of monthly rent
```

The calculated amount must be stored in the Booking.

---

# 25. Deposit

Deposit requirements can be expressed as:

```
NUMBER_OF_MONTHS
FIXED_AMOUNT
CUSTOM_AMOUNT
```

Example:

```
deposit_months = 5

monthly_rent = 150,000

deposit = 750,000
```

The actual deposit amount must be stored in the lease/booking transaction.

---

# 26. Lease

The Lease is the central legal/commercial agreement between tenant and property manager.

### Fields

```
id
lease_number

property_id
unit_id
tenant_id
booking_id

start_date
end_date

monthly_rent
deposit_amount
billing_frequency

payment_due_day

status

signed_at
activated_at
terminated_at

created_at
updated_at
```

### Lease status

```
DRAFT
PENDING_SIGNATURE
PARTIALLY_SIGNED
SIGNED
ACTIVE
EXPIRING
EXPIRED
TERMINATED
CANCELLED
```

---

# 27. Lease Terms

Create a separate entity:

```
LeaseTerm
```

This should contain commercial/legal terms.

Examples:

```
rent
deposit
billing frequency
notice period
renewal period
late payment fee
grace period
service charge
utility responsibility
maintenance responsibility
allowed business type
subletting policy
termination conditions
```

This makes the system flexible instead of hard-coding lease rules.

---

# 28. Lease Agreement Generation

The system should support document templates.

Example:

```
Lease Agreement Template
```

Variables:

```
{{tenant.name}}
{{tenant.business_name}}
{{property.name}}
{{property.address}}
{{unit.unit_number}}
{{lease.start_date}}
{{lease.end_date}}
{{lease.monthly_rent}}
{{lease.deposit_amount}}
```

The system generates:

```
PDF Lease Agreement
```

The generated document should be immutable/versioned.

---

# 29. Lease Signing

The tenant should be able to:

1. Open lease.
2. Download/view PDF.
3. Review terms.
4. Sign electronically.
5. Submit signed agreement.

The system should store:

```
LeaseSignature
```

Fields:

```
id
lease_id
user_id
signature_type
signature_data
signed_at
ip_address
user_agent
document_hash
```

Signature types:

```
DRAWN_SIGNATURE
UPLOADED_SIGNATURE
OTP_SIGNATURE
E_SIGNATURE_PROVIDER
```

For legally sensitive electronic signing, the implementation should later support a proper e-signature provider if required.

---

# 30. Lease Activation

A lease should only become ACTIVE when all mandatory conditions are fulfilled.

Example:

```
booking active
AND deposit paid
AND mandatory documents submitted
AND lease signed
AND property manager approved
```

Then:

```
lease.status = ACTIVE
unit = LEASED
```

---

# 31. Deposit Payment

Deposit should be represented financially as an invoice/charge rather than simply setting a Boolean.

Example:

```
Invoice:
Deposit for Unit A01

Amount:
KES 750,000

Status:
PAID
```

This gives the system a complete financial trail.

---

# 32. Invoice System

Invoices are generated from lease billing schedules.

Entity:

```
Invoice
```

Fields:

```
id
invoice_number

tenant_id
lease_id
property_id
unit_id

invoice_date
due_date

subtotal
tax
discount
total
amount_paid
amount_due

currency

status

created_at
updated_at
```

Status:

```
DRAFT
ISSUED
PARTIALLY_PAID
PAID
OVERDUE
CANCELLED
VOID
```

---

# 33. Invoice Lines

Never store only the total.

Create:

```
InvoiceLine
```

Example:

```
Monthly Rent          150,000
Service Charge         20,000
Water                   3,500
Electricity             7,000
Late Fee                2,000
--------------------------------
Subtotal               182,500
```

Fields:

```
id
invoice_id
description
quantity
unit_price
amount
tax_rate
tax_amount
line_type
reference_id
```

Line types:

```
RENT
DEPOSIT
BOOKING_FEE
SERVICE_CHARGE
ELECTRICITY
WATER
INTERNET
PARKING
LATE_FEE
OTHER
```

---

# 34. Invoice Generation Schedule

The system must support configurable invoice generation.

Example:

```
Rent due:
5th of every month

Generate invoice:
3rd of every month
```

The scheduler runs daily.

Pseudo logic:

```
FOR every active lease:

    IF today == configured invoice generation day:

        determine next billing period

        IF invoice does not already exist:

            generate invoice

            calculate rent

            calculate applicable charges

            calculate taxes

            calculate due date

            issue invoice

            notify tenant
```

The system must be idempotent.

Running the scheduler multiple times must never generate duplicate invoices.

---

# 35. Billing Period

Every invoice must have a billing period.

Example:

```
billing_period_start = 2026-09-01
billing_period_end = 2026-09-30
```

This is essential for:

- Reporting.
- Proration.
- Lease termination.
- Rent changes.
- Renewals.
- Disputes.

---

# 36. Payment System

Create a generic payment model.

```
Payment
```

Fields:

```
id
payment_reference

tenant_id
invoice_id
lease_id
property_id

amount
currency

payment_method
provider
provider_transaction_id

status

paid_at

created_at
updated_at
```

Payment methods:

```
MPESA
CARD
BANK_TRANSFER
CASH
CHEQUE
OTHER
```

Payment status:

```
PENDING
PROCESSING
SUCCESS
FAILED
CANCELLED
REFUNDED
PARTIALLY_REFUNDED
```

---

# 37. Payment Allocation

A payment should not necessarily belong to one invoice.

Create:

```
PaymentAllocation
```

Example:

Tenant pays:

```
KES 200,000
```

Outstanding invoices:

```
Invoice A: 150,000
Invoice B: 50,000
```

The system can allocate:

```
150,000 -> Invoice A
50,000  -> Invoice B
```

Fields:

```
id
payment_id
invoice_id
amount
allocated_at
```

---

# 38. Payment Provider Architecture

Payment providers must use an abstraction.

Example:

```
PaymentProvider
```

Interface:

```
initializePayment()
checkPaymentStatus()
handleWebhook()
refundPayment()
```

Providers:

```
MPESA
STRIPE
BANK
CARD
```

The application should not directly embed M-Pesa-specific logic into invoice controllers.

---

# 39. M-Pesa

For Kenya, M-Pesa should be supported as a first-class payment provider.

Potential flows:

```
STK Push
C2B
Paybill
Till
```

The payment service should:

1. Create payment intent.
2. Send payment request.
3. Store provider reference.
4. Wait for callback/webhook.
5. Verify callback.
6. Mark payment successful.
7. Allocate payment.
8. Update invoice.
9. Generate receipt.
10. Notify tenant.

Never trust only the mobile application’s payment result.

The server must verify payment through the provider callback/API.

---

# 40. Receipt

Every successful payment should generate a receipt.

Entity:

```
Receipt
```

Fields:

```
id
receipt_number
payment_id
tenant_id
property_id
amount
currency
issued_at
document_id
```

Receipt should be downloadable as PDF.

---

# 41. Platform Service Fee

The platform earns money by deducting a configurable service fee.

The fee system should be generic.

Entity:

```
FeeConfiguration
```

Possible fee types:

```
FIXED
PERCENTAGE
```

Possible fee basis:

```
PAYMENT
INVOICE
RENT
BOOKING
TRANSACTION
```

Example:

```
Platform fee = 2%

Tenant pays:
150,000

Platform fee:
3,000

Property manager receives:
147,000
```

The system must record both amounts.

Do not simply subtract the fee without creating a financial record.

---

# 42. Financial Ledger

For long-term reliability, the platform should eventually implement a ledger.

At minimum:

```
FinancialTransaction
```

with:

```
transaction_type
reference_type
reference_id
amount
currency
direction
status
created_at
```

Examples:

```
BOOKING_FEE
DEPOSIT
RENT
SERVICE_FEE
UTILITY
REFUND
PAYOUT
```

This becomes important once the platform manages money on behalf of property managers.

---

# 43. Property Manager Payouts

If tenants pay through the platform, the platform may collect money and later remit funds to property managers.

Create:

```
Payout
```

Fields:

```
id
organization_id
property_id

gross_amount
platform_fee
other_fees
net_amount

status
scheduled_at
paid_at

reference
```

Statuses:

```
PENDING
PROCESSING
PAID
FAILED
CANCELLED
```

---

# 44. Tenant Dashboard

The mobile home screen should show:

```
Current Property
Current Unit
Lease Status

Current Balance
Next Invoice
Next Payment Due Date

Recent Payments

Lease Expiry

Notifications
```

Example:

```
Sarit Estora
Unit A-102

Lease:
ACTIVE

Outstanding:
KES 150,000

Next payment:
5 September 2026

Next invoice:
KES 150,000
```

---

# 45. Tenant Mobile Navigation

Recommended structure:

```
Home
My Lease
Invoices
Payments
Documents
Property
Notifications
Profile
```

Future:

```
Utilities
Maintenance
Access
Parking
Staff
```

---

# 46. Property Manager Dashboard

Dashboard KPIs:

```
Total Units
Available Units
Reserved Units
Occupied Units
Occupancy Rate

Expected Monthly Rent
Collected This Month
Outstanding Amount
Overdue Amount

Active Tenants
Expiring Leases
Pending Bookings
Pending Lease Signatures
```

Charts:

```
Occupancy trend
Revenue trend
Collections trend
Outstanding balances
Unit distribution
```

---

# 47. Property Manager Unit View

A property manager should be able to see:

```
Unit
Status
Tenant
Monthly Rent
Deposit
Lease Start
Lease End
Outstanding Balance
```

Actions:

```
View
Edit
Reserve
Block
Lease
Terminate Lease
Change Price
View Tenant
View Payments
```

---

# 48. Unit Availability

The availability engine should consider:

```
Active Lease
Active Booking
Maintenance/Block
Future Reservation
```

A unit must not be double-booked.

Use database-level constraints/transactions where possible.

Booking creation should be atomic:

```
BEGIN TRANSACTION

Lock unit

Check availability

Create booking

Update reservation state

COMMIT
```

This prevents two tenants from booking the same unit simultaneously.

---

# 49. Notifications

Create a generic notification system.

Channels:

```
PUSH
SMS
EMAIL
IN_APP
```

Entity:

```
Notification
```

Types:

```
BOOKING_CREATED
BOOKING_EXPIRING
BOOKING_EXPIRED

PAYMENT_SUCCESS
PAYMENT_FAILED

INVOICE_GENERATED
INVOICE_DUE
INVOICE_OVERDUE

LEASE_READY
LEASE_SIGNED
LEASE_ACTIVATED
LEASE_EXPIRING

DOCUMENT_REQUIRED
```

---

# 50. Notification Templates

Templates should be configurable.

Example:

```
Invoice Generated

Hello {{tenant.name}},

Your rent invoice for {{property.name}}, Unit {{unit.unit_number}}
has been generated.

Amount: {{invoice.total}}
Due date: {{invoice.due_date}}
```

This avoids hard-coding notification content.

---

# 51. Document Management

Create:

```
Document
```

Fields:

```
id
owner_type
owner_id

document_type
file_name
file_url
mime_type
file_size

version
hash

status

created_at
updated_at
```

Document types:

```
LEASE_AGREEMENT
SIGNED_LEASE
RECEIPT
INVOICE
TENANT_ID
BUSINESS_REGISTRATION
TAX_CERTIFICATE
OTHER
```

---

# 52. Audit Logs

Every important administrative action should be logged.

Entity:

```
AuditLog
```

Fields:

```
id
user_id
organization_id
action
entity_type
entity_id
old_values
new_values
ip_address
user_agent
created_at
```

Examples:

```
UNIT_CREATED
UNIT_PRICE_CHANGED
BOOKING_APPROVED
LEASE_ACTIVATED
INVOICE_CANCELLED
PAYMENT_RECORDED
TENANT_UPDATED
```

Financial and lease changes should always be auditable.

---

# 53. Lease Termination

Termination must not simply delete a lease.

Process:

```
ACTIVE
   |
   v
TERMINATION_REQUESTED
   |
   v
APPROVED
   |
   v
TERMINATED
```

The system should calculate:

```
Outstanding rent
Outstanding utilities
Applicable penalties
Deposit deductions
Refundable deposit
```

Future version:

```
Move-out inspection
Damage assessment
Deposit settlement
Unit release
```

---

# 54. Lease Renewal

A lease should be renewable.

Process:

```
ACTIVE
   |
   v
EXPIRING
   |
   v
RENEWAL OFFER
   |
   v
TENANT ACCEPTS
   |
   v
NEW LEASE
```

Do not overwrite the historical lease.

Create a new lease version/record.

This preserves historical pricing and legal records.

---

# 55. Rent Changes

Rent changes should be effective-dated.

Example:

```
Lease 2026:
KES 150,000

Renewal 2027:
KES 165,000
```

The old invoices must continue showing KES 150,000.

Never dynamically recalculate historical invoices from current Unit pricing.

---

# 56. Proration

The billing engine should eventually support prorated rent.

Example:

Tenant starts on:

```
15 September
```

Monthly rent:

```
150,000
```

The system calculates the applicable partial-period amount based on configured proration rules.

Configuration:

```
ACTUAL_DAYS
30_DAY_MONTH
NO_PRORATION
```

---

# 57. Taxes

The billing engine should support taxes without assuming one specific country’s tax system.

Example:

```
VAT
```

Invoice:

```
Rent:       150,000
VAT:         27,000
-------------------
Total:      177,000
```

Tax configuration should support:

```
tax_name
rate
inclusive/exclusive
effective_from
effective_to
```

---

# 58. Service Charges

Service charges should eventually be supported as a separate billing component.

Examples:

```
Security
Cleaning
Common area maintenance
Waste management
Management fee
Parking
```

A lease may specify:

```
monthly service charge = KES 20,000
```

or:

```
service charge = KES 50/m²
```

The billing engine should support both.

---

# 59. Utility Architecture

Utilities should be designed as a separate module.

Core entities:

```
Utility
Meter
MeterReading
UtilityRate
UtilityBill
```

Example:

```
Unit A01
    |
    +-- Electricity Meter
    +-- Water Meter
    +-- Internet
```

Future smart meter integrations can push readings automatically.

---

# 60. Electricity Example

```
Previous reading:
15,000 kWh

Current reading:
15,150 kWh

Consumption:
150 kWh
```

Billing engine:

```
consumption × tariff
```

creates:

```
InvoiceLine:
Electricity
150 kWh × KES X
```

---

# 61. Maintenance Module

Future entity:

```
MaintenanceRequest
```

Fields:

```
id
property_id
unit_id
tenant_id
title
description
priority
category
status
assigned_to
created_at
resolved_at
```

Statuses:

```
OPEN
ASSIGNED
IN_PROGRESS
WAITING
RESOLVED
CLOSED
CANCELLED
```

Tenant mobile app:

```
Report Issue
Add photos
Describe issue
Track status
```

---

# 62. Access Control

Future integration:

```
Smart Lock
Access Card
QR Code
NFC
Biometric
```

Entities:

```
AccessDevice
AccessCredential
AccessPermission
AccessLog
```

A tenant’s active lease can determine access permissions.

Example:

```
Lease ACTIVE
    |
    v
Access enabled
```

Lease terminated:

```
Lease TERMINATED
    |
    v
Access disabled
```

---

# 63. Property Sales — Future

The system should eventually support sales.

Do not implement this into the leasing model.

Use:

```
Sale
SaleOffer
SaleAgreement
SalePayment
OwnershipTransfer
```

The same Property/Unit entities can be reused.

---

# 64. API Architecture

Recommended REST API structure:

```
/api/v1/auth

/api/v1/organizations

/api/v1/users

/api/v1/properties

/api/v1/buildings

/api/v1/floors

/api/v1/unit-types

/api/v1/units

/api/v1/tenants

/api/v1/bookings

/api/v1/leases

/api/v1/documents

/api/v1/invoices

/api/v1/payments

/api/v1/receipts

/api/v1/payouts

/api/v1/notifications

/api/v1/reports

/api/v1/settings

/api/v1/audit-logs
```

Future:

```
/api/v1/utilities
/api/v1/meters
/api/v1/meter-readings
/api/v1/maintenance
/api/v1/access
/api/v1/parking
```

---

# 65. API Design Principles

All APIs should:

- Use versioning.
- Validate input.
- Authenticate requests.
- Authorize access.
- Return consistent errors.
- Use pagination.
- Support filtering.
- Support sorting.
- Support search.
- Use idempotency for financial operations.
- Use transactions for financial/booking operations.
- Never expose sensitive internal fields.
- Never trust client-side calculated totals.

Example:

```
POST /api/v1/bookings
```

Request:

```json
{
  "unitId": "unit_123"
}
```

The server determines:

```
rent
deposit
booking fee
tax
expiry
```

The client should not submit authoritative financial amounts.

---

# 66. Idempotency

Financial APIs must support idempotency.

Example:

```
Idempotency-Key: booking-payment-123
```

If the same request arrives twice, the system must not:

- Charge twice.
- Create two payments.
- Create two invoices.
- Create two receipts.

This is critical for mobile networks and payment callbacks.

---

# 67. Background Jobs

The backend needs a job processing system.

Jobs include:

```
Expire bookings
Generate invoices
Send invoice notifications
Send payment reminders
Mark overdue invoices
Generate receipts
Generate lease documents
Process payment webhooks
Process payouts
Send SMS
Send emails
Send push notifications
Calculate utility bills
Lease expiry reminders
```

Use a queue rather than performing heavy work inside HTTP requests.

---

# 68. Scheduled Jobs

Examples:

### Every few minutes

```
Process payment callbacks
Expire bookings
Process notifications
```

### Daily

```
Generate upcoming invoices
Send payment reminders
Check lease expirations
Mark overdue invoices
```

### Monthly

```
Generate recurring rent invoices
Generate management reports
Calculate platform fees
Prepare payouts
```

---

# 69. Search

The system should provide global/search functionality.

Search by:

```
Tenant name
Phone
Email
Business name
Unit number
Lease number
Invoice number
Payment reference
Receipt number
Booking reference
```

---

# 70. Reporting

Initial reports:

### Occupancy Report

```
Total units
Occupied
Available
Reserved
Blocked
Occupancy percentage
```

### Revenue Report

```
Expected rent
Collected rent
Outstanding rent
Overdue rent
```

### Payment Report

```
Payment method
Transaction count
Total collected
Failed payments
Refunds
```

### Tenant Report

```
Active tenants
New tenants
Expired leases
Expiring leases
```

### Unit Report

```
Unit
Rent
Tenant
Lease
Status
Outstanding balance
```

---

# 71. Dashboard Calculations

Occupancy:

```
occupied_units / total_leasable_units × 100
```

Collection rate:

```
amount_collected / amount_due × 100
```

Outstanding:

```
total_invoiced - total_allocated_payments
```

These values should be derived from transactional data rather than manually stored whenever possible.

---

# 72. Mobile Application Authentication

Tenant authentication should support:

```
Phone number
OTP
Password
Biometric unlock
```

Recommended flow:

```
Phone
  |
  v
OTP
  |
  v
Authenticated
```

Refresh tokens should be securely stored on the device.

---

# 73. Web Authentication

Web application:

```
Email + password
MFA optional/required for administrators
```

Admin users should have stronger security requirements.

---

# 74. Security Requirements

The system must implement:

- RBAC.
- Tenant isolation.
- Organization isolation.
- Encryption at rest for sensitive information.
- HTTPS.
- Secure password hashing.
- Refresh token rotation.
- Rate limiting.
- CSRF protection where applicable.
- Input validation.
- SQL injection protection.
- File upload validation.
- File access authorization.
- Audit logging.
- Secure webhook verification.
- Payment signature verification.

A tenant must never be able to access another tenant’s:

```
invoice
payment
lease
document
unit
profile
```

even if they manually modify IDs in API requests.

---

# 75. File Storage

Documents should not be stored directly inside the database.

Use object storage.

Examples:

```
AWS S3
Cloudflare R2
DigitalOcean Spaces
```

Database stores:

```
file_key
file_url
metadata
hash
```

Access should preferably use signed URLs.

---

# 76. Frontend Architecture

The web application should be divided into modules.

```
Authentication
Dashboard
Properties
Buildings
Floors
Units
Unit Types
Bookings
Tenants
Leases
Invoices
Payments
Documents
Reports
Notifications
Settings
Users
Roles
Audit Logs
```

---

# 77. Tenant Mobile Screens

### Authentication

```
Splash
Login
Register
OTP
Forgot Password
```

### Main

```
Dashboard
Properties
Available Units
Unit Details
Booking
Booking Status
```

### Leasing

```
Lease
Lease Details
Lease Agreement
Sign Agreement
```

### Finance

```
Invoices
Invoice Details
Payment
Payment Status
Payment History
Receipt
```

### Account

```
Profile
Documents
Notifications
Settings
```

---

# 78. Property Manager Screens

```
Login

Dashboard

Properties
  - Property List
  - Property Details
  - Property Settings

Buildings
Floors

Units
  - Unit List
  - Unit Details
  - Create Unit
  - Batch Create Units
  - Unit Pricing
  - Unit Requirements

Bookings
  - Pending
  - Active
  - Expired
  - Cancelled

Tenants

Leases
  - Active
  - Pending Signature
  - Expiring
  - Expired
  - Terminated

Billing
  - Invoices
  - Payments
  - Receipts
  - Payouts

Reports

Documents

Notifications

Settings
```

---

# 79. Admin Screens

```
Dashboard

Organizations

Property Managers

Properties

Users

Roles & Permissions

Platform Fees

Payment Providers

Document Templates

Notification Templates

Transactions

Payouts

Audit Logs

System Settings
```

---

# 80. End-to-End Leasing Example

Assume:

```
Property:
Sarit Estora

Unit:
SHOP-101

Size:
50 × 100

Monthly rent:
KES 150,000

Deposit:
5 months

Deposit:
KES 750,000

Booking fee:
KES 20,000

Invoice generation:
3rd

Payment due:
5th
```

Tenant selects:

```
SHOP-101
```

System checks:

```
unit available?
yes
```

System creates:

```
Booking #BKG-00001
```

Booking fee:

```
KES 20,000
```

Tenant pays.

Payment:

```
SUCCESS
```

Booking:

```
ACTIVE
```

Unit:

```
RESERVED
```

Tenant completes required documents.

System generates:

```
Deposit Invoice
KES 750,000
```

Tenant pays deposit.

System generates:

```
Lease Agreement
```

Tenant signs.

Property manager approves.

Lease:

```
ACTIVE
```

Unit:

```
LEASED
```

On the configured invoice generation day:

```
3 September
```

System generates:

```
Rent Invoice

Rent:
KES 150,000

Due:
5 September
```

Tenant receives:

```
Push notification
SMS
Email
```

Tenant pays.

System:

```
Payment SUCCESS
Invoice PAID
Receipt GENERATED
Platform fee calculated
Property manager balance updated
```

---

# 81. Important State Machine

The core leasing state machine should be explicitly implemented.

```
UNIT

AVAILABLE
   |
   v
BOOKED
   |
   v
RESERVED
   |
   v
LEASED
```

Booking:

```
PENDING_PAYMENT
      |
      v
ACTIVE
      |
      +----> EXPIRED
      |
      +----> CANCELLED
      |
      v
CONVERTED_TO_LEASE
```

Lease:

```
DRAFT
 |
 v
PENDING_SIGNATURE
 |
 v
SIGNED
 |
 v
ACTIVE
 |
 +----> EXPIRING
 |
 +----> TERMINATED
 |
 v
EXPIRED
```

Invoice:

```
DRAFT
 |
 v
ISSUED
 |
 +----> PARTIALLY_PAID
 |            |
 |            v
 |           PAID
 |
 v
OVERDUE
```

Payment:

```
PENDING
 |
 v
PROCESSING
 |
 +----> FAILED
 |
 v
SUCCESS
 |
 +----> REFUNDED
```

---

# 82. Database Relationship Summary

Core relationships:

```
Organization
    |
    +-- Users
    |
    +-- Properties
            |
            +-- Buildings
            |     |
            |     +-- Floors
            |           |
            |           +-- Units
            |
            +-- Unit Types
            |
            +-- Tenants
            |
            +-- Bookings
            |
            +-- Leases
            |
            +-- Invoices
            |
            +-- Payments
```

Detailed:

```
Property 1---N Building

Building 1---N Floor

Floor 1---N Unit

Property 1---N UnitType

Unit 1---N UnitPricing

Unit 1---N UnitRequirement

Tenant 1---N Booking

Unit 1---N Booking

Booking 1---1 Lease

Tenant 1---N Lease

Unit 1---N Lease

Lease 1---N Invoice

Invoice 1---N InvoiceLine

Tenant 1---N Payment

Payment N---N Invoice
through PaymentAllocation

Payment 1---1 Receipt

Lease 1---N Document

Lease 1---N LeaseSignature
```

---

# 83. Database Design Principles

Use UUIDs or equivalent non-sequential public identifiers.

Every primary entity should have:

```
id
created_at
updated_at
```

Soft deletion should be used selectively.

Do not soft-delete financial records.

Invoices, payments, receipts and leases should remain historically accessible.

Use database transactions for:

```
Booking creation
Lease activation
Payment processing
Payment allocation
Invoice generation
Payout generation
```

---

# 84. Financial Data Rules

These rules are mandatory.

### Rule 1

Never modify a historical payment amount.

### Rule 2

Never delete successful payments.

### Rule 3

Never modify a paid invoice.

If correction is required:

```
Credit Note
Debit Note
Adjustment
```

should be introduced.

### Rule 4

Historical invoices must retain their original pricing.

### Rule 5

Every financial transaction must have a reference.

### Rule 6

Payment callbacks must be idempotent.

### Rule 7

Financial totals should be calculated server-side.

---

# 85. Auditability

For any financial dispute, the system should be able to answer:

```
Who created the invoice?
When was it created?
What lease generated it?
What amount was originally charged?
Who paid?
When did they pay?
Which payment provider processed it?
What was the provider reference?
Which invoice was the payment allocated to?
Was a platform fee deducted?
How much was remitted to the property manager?
```

This should be a fundamental design principle.

---

# 86. MVP Scope

The first production version should NOT attempt to build everything.

MVP should contain:

## Property Management

- Organizations.
- Users.
- Properties.
- Buildings.
- Floors.
- Units.
- Unit types.
- Batch unit creation.
- Unit pricing.
- Unit requirements.

## Leasing

- Tenant registration.
- Unit browsing.
- Booking.
- Booking fees.
- Booking expiration.
- Deposit calculation.
- Lease generation.
- Lease signing.
- Lease activation.
- Lease termination.

## Billing

- Invoices.
- Invoice lines.
- Recurring rent.
- Due dates.
- Overdue status.
- Payments.
- Payment allocation.
- Receipts.

## Payments

- M-Pesa.
- Payment webhook processing.
- Payment status.
- Platform fee calculation.

## Notifications

- Push.
- SMS.
- Email.
- In-app notifications.

## Reporting

- Occupancy.
- Revenue.
- Outstanding invoices.
- Collections.

---

# 87. Phase 2

Add:

```
Utilities
Meters
Water
Electricity
Internet
Maintenance
Service charges
Parking
Tenant staff
Access control
Advanced reporting
```

---

# 88. Phase 3

Add:

```
Property owners
Property portfolios
Property sales
Commission management
Advanced accounting
Payout automation
Advanced e-signatures
Smart locks
IoT meter integration
BI dashboards
```

---

# 89. Recommended Backend Modules

The backend should be modular.

```
auth
organizations
users
roles
properties
buildings
floors
units
unit-types
tenants
bookings
leases
documents
billing
invoices
payments
receipts
payouts
fees
notifications
reports
audit
```

Each module should contain:

```
controller
service
repository/data-access
validation
types
routes
tests
```

Business logic should live in services/domain logic rather than controllers.

---

# 90. Recommended Frontend Modules

Web:

```
auth
dashboard
properties
units
bookings
tenants
leases
billing
payments
reports
documents
notifications
settings
```

Mobile:

```
auth
home
properties
units
bookings
leases
invoices
payments
documents
notifications
profile
```

---

# 91. Backend Development Order

Build in this order:

```
1. Authentication
2. Organizations
3. RBAC
4. Properties
5. Buildings/Floors
6. Units
7. Unit Types
8. Tenants
9. Booking engine
10. Booking payment
11. Lease engine
12. Document generation
13. Lease signing
14. Invoice engine
15. Payment engine
16. M-Pesa integration
17. Receipts
18. Platform fees
19. Notifications
20. Reports
21. Audit logs
```

Do not start with dashboards.

The domain and transactional workflows must exist first.

---

# 92. Frontend Development Order

```
1. Authentication
2. Property setup
3. Unit management
4. Tenant onboarding
5. Unit browsing
6. Booking
7. Lease management
8. Documents
9. Invoices
10. Payments
11. Notifications
12. Dashboards
13. Reports
```

---

# 93. Testing Requirements

Every major business workflow requires automated tests.

### Booking tests

```
Can book available unit
Cannot book leased unit
Cannot double-book unit
Booking expires correctly
Expired booking releases unit
Payment activates booking
```

### Lease tests

```
Cannot activate without deposit
Cannot activate without signature
Lease activates correctly
Unit becomes leased
Lease termination works
```

### Billing tests

```
Invoice generated once
No duplicate invoice
Correct billing period
Correct rent
Correct deposit
Correct due date
Overdue detection works
```

### Payment tests

```
Successful payment
Failed payment
Duplicate webhook
Payment allocation
Partial payment
Overpayment
Refund
```

---

# 94. Acceptance Criteria for MVP

The MVP should be considered functional when the following complete workflow works end-to-end:

```
Admin creates organization
        |
        v
Property manager creates estora
        |
        v
Property manager creates unit types
        |
        v
System generates units
        |
        v
Manager configures rent/deposit/booking fee
        |
        v
Tenant creates account
        |
        v
Tenant views available unit
        |
        v
Tenant books unit
        |
        v
Tenant pays booking fee
        |
        v
Booking becomes active
        |
        v
Tenant submits requirements
        |
        v
System generates lease
        |
        v
Tenant signs lease
        |
        v
Tenant pays deposit
        |
        v
Manager approves lease
        |
        v
Lease becomes active
        |
        v
Unit becomes leased
        |
        v
Recurring billing engine generates rent invoice
        |
        v
Tenant receives notification
        |
        v
Tenant pays invoice
        |
        v
Payment verified
        |
        v
Invoice marked paid
        |
        v
Receipt generated
        |
        v
Platform fee calculated
        |
        v
Property manager balance updated
```

If this workflow works reliably, the platform has a solid MVP.

---

# 95. Important Architectural Principle

Do not build this as:

```
Estora CRUD
+
Tenant CRUD
+
Invoice CRUD
```

Build it around business processes:

```
Property
    ↓
Unit
    ↓
Availability
    ↓
Booking
    ↓
Lease
    ↓
Billing
    ↓
Payment
    ↓
Settlement
```

This distinction is extremely important.

The system’s value is not the ability to create units.

The value is the ability to manage the entire lifecycle of a commercial space.

---

# 96. LLM Implementation Instructions

When giving this specification to an LLM for implementation, the LLM should follow these rules:

1. Do not invent business rules that contradict this specification.
2. Do not simplify financial models into fields on unrelated entities.
3. Keep financial transactions immutable.
4. Use database transactions for financial and booking operations.
5. Implement authorization at the service/API layer.
6. Never trust client-provided financial calculations.
7. Never expose another tenant’s data.
8. Use background jobs for scheduled operations.
9. Make scheduled jobs idempotent.
10. Make payment webhooks idempotent.
11. Preserve historical pricing.
12. Preserve historical lease records.
13. Do not delete financial records.
14. Use effective dates for pricing changes.
15. Separate domain logic from controllers.
16. Write tests for every state transition.
17. Do not implement future modules prematurely unless they affect the MVP architecture.
18. Keep utility, maintenance, access control and sales modules extensible but separate.
19. Use consistent API response/error formats.
20. Document all non-obvious business logic.

---

# 97. Suggested Initial Repository Structure

```
backend/
    src/
        modules/
            auth/
            organizations/
            users/
            roles/
            properties/
            buildings/
            floors/
            units/
            unit-types/
            tenants/
            bookings/
            leases/
            documents/
            billing/
            invoices/
            payments/
            receipts/
            fees/
            payouts/
            notifications/
            reports/
            audit/

        infrastructure/
            database/
            storage/
            payments/
            messaging/
            queue/

        shared/
            errors/
            middleware/
            validation/
            utils/
            types/

        jobs/

        config/

        app.ts
        server.ts
```

Frontend:

```
web/
    src/
        modules/
            auth/
            dashboard/
            properties/
            units/
            bookings/
            tenants/
            leases/
            billing/
            payments/
            documents/
            reports/
            settings/

        components/
        layouts/
        routes/
        services/
        hooks/
        utils/
```

Mobile:

```
mobile/
    src/
        modules/
            auth/
            home/
            properties/
            bookings/
            leases/
            invoices/
            payments/
            documents/
            notifications/
            profile/

        components/
        navigation/
        services/
        hooks/
        storage/
        utils/
```

---

# 98. Final Product Definition

The platform should ultimately be thought of as:

> **A commercial property operating system that manages the complete lifecycle of leasable spaces, from availability and booking through leasing, billing, payments and tenant operations.**
> 

The first version focuses on:

```
PROPERTY
    ↓
UNIT
    ↓
BOOKING
    ↓
LEASE
    ↓
INVOICE
    ↓
PAYMENT
    ↓
RECEIPT
    ↓
SETTLEMENT
```

Everything else should plug into this lifecycle.

The architecture should therefore be designed around **property, tenancy, financial transactions, documents, workflows and events**, rather than around individual screens.

This allows the same platform to eventually manage:

```
Estoras
Shopping Centres
Office Buildings
Warehouses
Business Centres
Mixed-Use Developments
```

and eventually:

```
Leasing
Utilities
Maintenance
Parking
Access Control
Facility Management
Property Sales
Property Ownership
```

without having to rebuild the core platform.