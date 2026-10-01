import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_skeleton.dart';

/// Displays local or remote media with one loading and failure treatment.
///
/// Sources beginning with `http://` or `https://` use [Image.network]; every
/// other non-empty source uses [Image.asset]. A null or failed source renders
/// a randomly chosen bundled property placeholder, stable while displayed.
class AppMedia extends StatelessWidget {
  const AppMedia({
    this.source,
    this.fit = BoxFit.cover,
    this.height,
    this.width = double.infinity,
    this.aspectRatio = 16 / 10,
    this.borderRadius,
    this.fallbackIcon = Icons.apartment_rounded,
    this.semanticLabel,
    this.heroTag,
    this.overlay,
    this.backgroundColor,
    super.key,
  });

  final String? source;
  final BoxFit fit;
  final double? height;
  final double? width;
  final double? aspectRatio;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  /// What shows for the frame before the image decodes.
  ///
  /// Defaults to a tonal surface, which is right in a card. Pass a dark colour
  /// when light text sits on the image: the header's scrims are tuned for a
  /// photograph, and a pale ground behind them for one frame is a flash of
  /// unreadable white-on-cream.
  final Color? backgroundColor;
  final String? semanticLabel;
  final Object? heroTag;
  final Widget? overlay;

  bool get _isRemote {
    final value = source?.trim().toLowerCase();
    return value?.startsWith('https://') == true ||
        value?.startsWith('http://') == true;
  }

  @override
  Widget build(BuildContext context) {
    Widget media = LayoutBuilder(
      builder: (context, constraints) {
        // Bucket widths to avoid new cache entries for every layout pixel.
        // Hero flights retain enough detail for the expanded destination.
        final logicalWidth = heroTag == null
            ? constraints.maxWidth
            : max(constraints.maxWidth, MediaQuery.sizeOf(context).width);
        final pixels = logicalWidth * MediaQuery.devicePixelRatioOf(context);
        final decodeWidth = pixels.isFinite && pixels > 0
            ? (pixels / 64).ceil() * 64
            : null;
        return Stack(
          fit: StackFit.expand,
          children: [_image(decodeWidth), ?overlay],
        );
      },
    );

    media = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: ColoredBox(
        color:
            backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainerHigh,
        child: media,
      ),
    );

    if (heroTag != null) media = Hero(tag: heroTag!, child: media);

    Widget result;
    if (aspectRatio != null && height == null) {
      result = SizedBox(
        width: width,
        child: AspectRatio(aspectRatio: aspectRatio!, child: media),
      );
    } else {
      result = SizedBox(width: width, height: height, child: media);
    }

    return Semantics(
      image: true,
      label: semanticLabel ?? 'Property image',
      container: true,
      explicitChildNodes: true,
      excludeSemantics: true,
      child: result,
    );
  }

  Widget _image(int? decodeWidth) {
    final value = source?.trim();
    if (value == null || value.isEmpty) {
      return _placeholder(decodeWidth);
    }

    if (_isRemote) {
      return Image.network(
        value,
        cacheWidth: decodeWidth,
        fit: fit,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => _placeholder(decodeWidth),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const AppSkeleton(height: double.infinity),
        frameBuilder: _fadeInFrame,
      );
    }

    return Image.asset(
      value,
      cacheWidth: decodeWidth,
      fit: fit,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => _placeholder(decodeWidth),
      frameBuilder: _fadeInFrame,
    );
  }

  Widget _placeholder(int? decodeWidth) => _PropertyPlaceholder(
    fit: fit,
    fallbackIcon: fallbackIcon,
    decodeWidth: decodeWidth,
  );

  Widget _fadeInFrame(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: AppMotion.standard,
      curve: AppMotion.enter,
      child: child,
    );
  }
}

class _PropertyPlaceholder extends StatefulWidget {
  const _PropertyPlaceholder({
    required this.fit,
    required this.fallbackIcon,
    this.decodeWidth,
  });

  final int? decodeWidth;

  final BoxFit fit;
  final IconData fallbackIcon;

  @override
  State<_PropertyPlaceholder> createState() => _PropertyPlaceholderState();
}

class _PropertyPlaceholderState extends State<_PropertyPlaceholder> {
  static const _assets = [
    'assets/images/property_placeholder.webp',
    'assets/images/property_placeholder_2.webp',
    'assets/images/property_placeholder_3.webp',
    'assets/images/property_placeholder_4.webp',
    'assets/images/property_placeholder_5.webp',
  ];

  late final _asset = _assets[Random().nextInt(_assets.length)];

  @override
  Widget build(BuildContext context) => Image.asset(
    _asset,
    cacheWidth: widget.decodeWidth,
    fit: widget.fit,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => _MediaFallback(icon: widget.fallbackIcon),
  );
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.secondaryContainer, scheme.primaryContainer],
        ),
      ),
      child: Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.84),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: scheme.primary),
        ),
      ),
    );
  }
}
