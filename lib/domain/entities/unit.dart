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
    this.ratePerSqm,
    this.rentOverridden = false,
    this.requirements = const <UnitRequirement>[],
    this.imageUrls = const <String>[],
    this.category = UnitCategory.unknown,
    this.wing,
    this.section,
    this.floorNumber,
    this.depositAmount,
    this.serviceCharge,
    this.availableFrom,
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

  /// What kind of space this is — a shop, a kiosk, a restaurant.
  ///
  /// Distinct from [unitTypeId], which points at a batch-creation template.
  /// Two units built from the same template are both shops; a shop and a
  /// kiosk in the same wing were built from different ones.
  final UnitCategory category;

  /// Where in the building. The contract carries these as loose labels rather
  /// than references, and they are kept that way — a wing called "East" is not
  /// an entity anyone maintains.
  final String? wing;
  final String? section;
  final int? floorNumber;

  /// The deposit as a cash figure, where the server states one outright rather
  /// than as a multiple of rent. Both forms exist in the contract; whichever
  /// arrives is what gets shown.
  final Money? depositAmount;

  final Money? serviceCharge;

  /// When the unit can next be occupied.
  final DateTime? availableFrom;

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

  /// The rate [baseRent] was derived from, denormalised so a rent can explain
  /// itself in a list without a lookup back to the property.
  ///
  /// Null when the property is priced unit by unit rather than by area.
  final Money? ratePerSqm;

  /// Whether [baseRent] was set by hand rather than derived from [ratePerSqm].
  ///
  /// An overridden rent survives a repricing of the property — the corner shop
  /// an owner deliberately priced above the rate does not quietly fall back to
  /// it the next time the rate moves.
  final bool rentOverridden;

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

  /// `KES 30 / m²`, or null if this rent was not derived from a rate.
  String? get rateLabel {
    final rate = ratePerSqm;
    return rate == null ? null : '${rate.format()} / $areaUnit';
  }

  String get locationLabel => [
    propertyName,
    buildingName,
    floorName,
  ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');

  List<UnitRequirement> get mandatoryRequirements =>
      requirements.where((r) => r.isMandatory).toList(growable: false);

  static String _trim(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

/// Section 48's availability engine, answered for one block.
///
/// This is the server's word on what a tenant could book right now: the
/// block, and within it the unit sizes with stock and how many of each. It
/// carries no unit ids, so it cannot be shown as a list of spaces on its
/// own — it says which of a block's units are worth fetching.
class UnitAvailability {
  const UnitAvailability({
    required this.propertyId,
    required this.propertyName,
    required this.blockId,
    required this.blockName,
    required this.bySize,
  });

  final String propertyId;
  final String propertyName;
  final String blockId;
  final String blockName;

  /// Sizes with bookable stock, in the area unit the server measures in.
  final List<UnitAvailabilitySize> bySize;

  /// Units in this block, in total, that could be booked.
  int get count => bySize.fold(0, (sum, size) => sum + size.count);

  /// Whether a unit of [area] in this block has bookable stock.
  bool offers(double? area) =>
      area != null && bySize.any((s) => s.count > 0 && s.size == area);
}

class UnitAvailabilitySize {
  const UnitAvailabilitySize({required this.size, required this.count});

  final double size;
  final int count;
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
    this.ratePerSqm,
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

  /// Overrides the property's rate for units built from this type — a kiosk
  /// commands more per square metre than a warehouse bay in the same building.
  ///
  /// Null means the units inherit `Property.rentRatePerSqm`.
  final Money? ratePerSqm;
}

/// What an owner submits to create or amend a single unit.
///
/// The batch draft in `owner.dart` builds a floor of identical shops in one
/// go; this is the other half of the job — the one unit that is not like the
/// others, and the correction to a unit that already exists.
///
/// The deposit and booking fee can each be stated as a cash amount *or* as a
/// percentage of rent, because the contract accepts both and back offices use
/// both. Nothing here converts between them: whichever the owner entered is
/// what gets sent.
class UnitDraft {
  const UnitDraft({
    required this.propertyId,
    required this.unitNumber,
    required this.category,
    required this.monthlyRent,
    this.blockId,
    this.description,
    this.length,
    this.width,
    this.area,
    this.bookingFeeType,
    this.depositAmount,
    this.depositPercentage,
    this.serviceCharge,
    this.bookingFeePercentage,
    this.wing,
    this.section,
    this.floorNumber,
  });

  /// Seeds the form from a unit that already exists.
  UnitDraft.from(Unit unit)
    : propertyId = unit.propertyId,
      blockId = unit.buildingId,
      unitNumber = unit.unitNumber,
      category = unit.category,
      monthlyRent = unit.baseRent,
      description = unit.description,
      length = unit.length,
      width = unit.width,
      area = unit.area,
      bookingFeeType = null,
      depositAmount = unit.depositAmount,
      depositPercentage = null,
      serviceCharge = unit.serviceCharge,
      bookingFeePercentage = null,
      wing = unit.wing,
      section = unit.section,
      floorNumber = unit.floorNumber;

  final String propertyId;
  final String? blockId;
  final String unitNumber;
  final UnitCategory category;
  final String? description;

  final double? length;
  final double? width;
  final double? area;

  final Money monthlyRent;

  final String? bookingFeeType;
  final Money? depositAmount;
  final double? depositPercentage;
  final Money? serviceCharge;
  final double? bookingFeePercentage;

  final String? wing;
  final String? section;
  final int? floorNumber;
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
