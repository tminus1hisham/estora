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

  final String? logoUrl;
  final String? imageUrl;

  String get locationLabel => [
    if (address != null && address!.isNotEmpty) address,
    city,
    country,
  ].whereType<String>().join(', ');

  bool get hasAvailability => (availableUnits ?? 0) > 0;
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
