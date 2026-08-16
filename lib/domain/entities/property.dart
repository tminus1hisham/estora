import '../../core/utils/money.dart';
import '../enums/domain_enums.dart';

/// Section 11. A mall or other commercial property.
///
/// The spec is explicit (section 2) that "mall" must not be hard-coded into the
/// model — a property carries a [PropertyType] instead, so the same screens
/// serve an office block or a warehouse without change.
class Property {
  const Property({
    required this.id,
    required this.name,
    required this.code,
    required this.propertyType,
    required this.status,
    required this.city,
    required this.country,
    this.description,
    this.address,
    this.county,
    this.latitude,
    this.longitude,
    this.totalArea,
    this.totalUnits,
    this.availableUnits,
    this.ownerId,
    this.rentRatePerSqm,
    this.logoUrl,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String code;
  final PropertyType propertyType;
  final PropertyStatus status;

  final String? description;
  final String? address;
  final String city;
  final String? county;
  final String country;
  final double? latitude;
  final double? longitude;

  final double? totalArea;
  final int? totalUnits;

  /// Count of units a tenant could book right now. Derived server-side from
  /// bookings and leases (section 15 prefers deriving occupancy over storing
  /// it), so the app just displays what it is given.
  final int? availableUnits;

  /// Section 88. Who owns the property, if the platform is tracking ownership.
  ///
  /// Null for a property that predates owner accounts. Kept as an edge here
  /// rather than a list on [PropertyOwner] so a property can change hands
  /// without rewriting the owner.
  final String? ownerId;

  /// What the property asks per square metre, per billing period.
  ///
  /// This is the figure an owner sets, and every unit's [Unit.baseRent] is
  /// derived from it server-side as `area × rate`. It is a *listing* rate: a
  /// change reprices unlet units only, and never reaches a lease that has
  /// already been signed.
  ///
  /// Null for a property priced unit by unit, which is every property that
  /// existed before owners could set a rate.
  final Money? rentRatePerSqm;

  final String? logoUrl;
  final String? imageUrl;

  String get locationLabel => [
    if (address != null && address!.isNotEmpty) address,
    city,
    country,
  ].whereType<String>().join(', ');

  bool get hasAvailability => (availableUnits ?? 0) > 0;

  /// `KES 30 / m²`, or null if the property is not priced by area.
  String? get rateLabel {
    final rate = rentRatePerSqm;
    return rate == null ? null : '${rate.format()} / m²';
  }
}

/// Section 13. A wing or block within a property.
class Building {
  const Building({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.code,
    this.description,
  });

  final String id;
  final String propertyId;
  final String name;
  final String code;
  final String? description;
}

/// Section 14.
class Floor {
  const Floor({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.floorNumber,
    this.description,
  });

  final String id;
  final String buildingId;
  final String name;
  final int floorNumber;
  final String? description;
}
