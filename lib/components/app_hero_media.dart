import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_media.dart';

/// Resilient property media with a premium placeholder and graceful fallback.
/// Provide either [imageUrl] or [assetPath]; when both are absent the fallback
/// is shown immediately.
class AppHeroMedia extends StatelessWidget {
  const AppHeroMedia({
    this.imageUrl,
    this.assetPath,
    this.height,
    this.aspectRatio = 16 / 10,
    this.fit = BoxFit.cover,
    this.borderRadius = AppRadius.lg,
    this.heroTag,
    this.overlay,
    this.fallbackIcon = Icons.apartment_rounded,
    this.semanticLabel,
    super.key,
  }) : assert(
         imageUrl == null || assetPath == null,
         'Provide imageUrl or assetPath, not both.',
       );

  final String? imageUrl;
  final String? assetPath;
  final double? height;
  final double aspectRatio;
  final BoxFit fit;
  final double borderRadius;
  final Object? heroTag;
  final Widget? overlay;
  final IconData fallbackIcon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return AppMedia(
      source: assetPath ?? imageUrl,
      fit: fit,
      height: height,
      aspectRatio: height == null ? aspectRatio : null,
      borderRadius: BorderRadius.circular(borderRadius),
      fallbackIcon: fallbackIcon,
      semanticLabel: semanticLabel,
      heroTag: heroTag,
      overlay: overlay,
    );
  }
}
