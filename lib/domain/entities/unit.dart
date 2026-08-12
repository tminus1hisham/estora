import '../../core/utils/money.dart';
import '../enums/domain_enums.dart';

/// Section 15. A physical leasable space.
class Unit {
  const Unit({
    required this.id,
    required this.propertyId,
    required this.unitNumber,
    required this.unitCode,
    required this.status,
    required this.baseRent,
    required this.billingFrequency,
    this.buildingId,
    this.floorId,
    this.name,
    this.description,
    this.unitTypeId,
    this.length,
    this.width,
    this.area,
    this.areaUnit = 'm²',
    this.propertyName,
    this.buildingName,
    this.floorName,
    this.depositMonths,
    this.bookingFee,
    this.requirements = const <UnitRequirement>[],
    this.imageUrls = const <String>[],
  });

  final String id;
  final String propertyId;
  final String? buildingId;
  final String? floorId;

  final String unitNumber;
  final String unitCode;
  final String? name;
  final String? description;

  final String? unitTypeId;

  final double? length;
  final double? width;
  final double? area;
  final String areaUnit;

  /// The unit's current asking rent.
  ///
  /// This is a *listing* price only. Once a booking exists it captures its own
  /// terms (section 21) and once a lease exists it carries its own rent
  /// (section 55), and neither is ever re-derived from this field.
  final Money baseRent;
  final BillingFrequency billingFrequency;

  final UnitStatus status;

  /// Deposit expressed in months of rent (section 25). The actual deposit
  /// amount is computed and stored server-side on the booking and lease.
  final int? depositMonths;

  /// Indicative booking fee (section 24). The authoritative figure comes back
  /// on the booking quote.
  final Money? bookingFee;

  final List<UnitRequirement> requirements;

  /// Denormalised for list rendering, so a unit card does not need three extra
  /// lookups to show "Sarit Mall · East Wing · Ground Floor".
  final String? propertyName;
  final String? buildingName;
  final String? floorName;

  final List<String> imageUrls;

  bool get isBookable => status.isBookable;

  /// `50 × 100 m²`
  String? get dimensionsLabel {
    if (length == null || width == null) return null;
    return '${_trim(length!)} × ${_trim(width!)}';
  }

  String? get areaLabel => area == null ? null : '${_trim(area!)} $areaUnit';

  String get locationLabel => [
    propertyName,
    buildingName,
    floorName,
  ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');

  List<UnitRequirement> get mandatoryRequirements =>
      requirements.where((r) => r.isMandatory).toList(growable: false);

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();
}

/// Section 16. A template used for batch unit creation (section 17).
///
/// The tenant app only reads unit types — for filtering the browse list by
/// "50x100 Retail Unit" — since creation lives in the property manager web app.
class UnitType {
  const UnitType({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.code,
    required this.baseRent,
    this.description,
    this.length,
    this.width,
    this.area,
    this.defaultDepositMonths,
    this.defaultBookingFee,
  });

  final String id;
  final String propertyId;
  final String name;
  final String code;
  final String? description;
  final double? length;
  final double? width;
  final double? area;
  final Money baseRent;
  final int? defaultDepositMonths;
  final Money? defaultBookingFee;
}

/// Section 19. Effective-dated pricing, so a rent increase never rewrites
/// history.
class UnitPricing {
  const UnitPricing({
    required this.id,
    required this.unitId,
    required this.billingFrequency,
    required this.amount,
    required this.effectiveFrom,
    required this.isActive,
    this.effectiveTo,
  });

  final String id;
  final String unitId;
  final BillingFrequency billingFrequency;
  final Money amount;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final bool isActive;
}

/// Section 18. Something the tenant must satisfy before a lease can activate.
class UnitRequirement {
  const UnitRequirement({
    required this.id,
    required this.unitId,
    required this.requirementType,
    required this.name,
    required this.isMandatory,
    this.description,
    this.value,
    this.isSatisfied = false,
    this.documentType,
  });

  final String id;
  final String unitId;
  final RequirementType requirementType;
  final String name;
  final String? description;
  final bool isMandatory;

  /// Free-form value, e.g. `5` for a deposit expressed in months.
  final String? value;

  /// Whether this tenant has met the requirement.
  ///
  /// Server-evaluated. Section 30 makes lease activation conditional on all
  /// mandatory requirements being satisfied, and that decision is not the
  /// client's to make — this flag is for display and to decide which upload
  /// prompts to show.
  final bool isSatisfied;

  /// For [RequirementType.document] requirements, which document type satisfies
  /// this requirement.
  final DocumentType? documentType;
}
