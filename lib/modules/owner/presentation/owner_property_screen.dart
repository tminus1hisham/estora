import 'package:flutter/material.dart';

import '../../properties/presentation/property_detail_screen.dart';

/// The selected property's record, loaded from the property API.
class OwnerPropertyScreen extends StatelessWidget {
  const OwnerPropertyScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  Widget build(BuildContext context) =>
      PropertyDetailScreen(propertyId: propertyId, manager: true);
}
