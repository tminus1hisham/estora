import '../../core/utils/money.dart';
import '../enums/domain_enums.dart';
import 'owner.dart';

/// Section 11. A estora or other commercial property.
///
/// The spec is explicit (section 2) that "estora" must not be hard-coded into the
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
    this.mix,
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

  /// How the units are let, counted from the unit records the payload
  /// embeds. Null when it embeds none — a property list is not asked to fetch
  /// every unit just to put a percentage on a card.
  final UnitMix? mix;

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
///
/// The contract calls this a `PropertyBlock` and gives it a lifecycle and a
/// size of its own: a wing can be under construction while the estora around it
/// trades, and it can be counted and measured separately. Those fields are
/// nullable because the tenant-facing browse screens have always been able to
/// render a block knowing only its name.
class Building {
  const Building({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.code,
    this.description,
    this.status = BlockStatus.active,
    this.totalArea,
    this.numberOfFloors,
    this.totalUnits,
    this.leasableUnits,
    this.propertyName,
  });

  final String id;
  final String propertyId;
  final String name;
  final String code;
  final String? description;

  final BlockStatus status;
  final double? totalArea;
  final int? numberOfFloors;
  final int? totalUnits;
  final int? leasableUnits;

  /// Denormalised so a block can name its property in a list without a lookup.
  final String? propertyName;

  /// `4 floors · 32 units`, or as much of it as the server actually said.
  String get shapeLabel => [
    if (numberOfFloors != null)
      '$numberOfFloors ${numberOfFloors == 1 ? 'floor' : 'floors'}',
    if (totalUnits != null) '$totalUnits ${totalUnits == 1 ? 'unit' : 'units'}',
  ].join(' · ');
}

/// What an owner submits to create or amend a block.
class BuildingDraft {
  const BuildingDraft({
    required this.propertyId,
    required this.name,
    required this.status,
    this.description,
    this.totalArea,
    this.numberOfFloors,
    this.totalUnits,
    this.leasableUnits,
  });

  /// Seeds the form from a block that already exists.
  BuildingDraft.from(Building building)
    : propertyId = building.propertyId,
      name = building.name,
      status = building.status,
      description = building.description,
      totalArea = building.totalArea,
      numberOfFloors = building.numberOfFloors,
      totalUnits = building.totalUnits,
      leasableUnits = building.leasableUnits;

  final String propertyId;
  final String name;
  final BlockStatus status;
  final String? description;
  final double? totalArea;
  final int? numberOfFloors;
  final int? totalUnits;
  final int? leasableUnits;
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
