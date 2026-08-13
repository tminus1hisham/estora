import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_tokens.dart';
import 'status_palette.dart';

export 'app_gradients.dart';
export 'app_palette.dart';
export 'app_tokens.dart';

/// Premium light and dark themes for the tenant experience.
///
/// The palette is explicit rather than generated from a seed. This keeps
/// financial states, photography surfaces and platform controls consistent
/// across Flutter SDK updates.
abstract final class AppTheme {
  /// Kept for backwards compatibility with any per-property branding code.
  static const Color seed = AppPalette.azure700;

  static ThemeData get light => _build(_lightScheme, StatusColors.light);

  static ThemeData get dark => _build(_darkScheme, StatusColors.dark);

  static const ColorScheme _lightScheme = ColorScheme.light(
    primary: AppPalette.azure700,
    onPrimary: AppPalette.stone0,
    primaryContainer: AppPalette.azure100,
    onPrimaryContainer: AppPalette.azure950,
    primaryFixed: AppPalette.azure100,
    primaryFixedDim: AppPalette.azure200,
    onPrimaryFixed: AppPalette.azure950,
    onPrimaryFixedVariant: AppPalette.azure800,
    secondary: AppPalette.navy800,
    onSecondary: AppPalette.stone0,
    secondaryContainer: AppPalette.stone200,
    onSecondaryContainer: AppPalette.navy900,
    secondaryFixed: AppPalette.stone100,
    secondaryFixedDim: AppPalette.stone300,
    onSecondaryFixed: AppPalette.navy950,
    onSecondaryFixedVariant: AppPalette.navy700,
    tertiary: AppPalette.brass700,
    onTertiary: AppPalette.stone0,
    tertiaryContainer: AppPalette.brass100,
    onTertiaryContainer: AppPalette.navy900,
    tertiaryFixed: AppPalette.brass100,
    tertiaryFixedDim: AppPalette.brass200,
    onTertiaryFixed: AppPalette.navy950,
    onTertiaryFixedVariant: AppPalette.brass700,
    error: AppPalette.red700,
    onError: AppPalette.stone0,
    errorContainer: AppPalette.red100,
    onErrorContainer: Color(0xFF641E1A),
    surface: AppPalette.stone50,
    onSurface: AppPalette.navy900,
    surfaceDim: AppPalette.stone200,
    surfaceBright: AppPalette.stone0,
    surfaceContainerLowest: AppPalette.stone0,
    surfaceContainerLow: Color(0xFFF7F4EE),
    surfaceContainer: AppPalette.stone100,
    surfaceContainerHigh: AppPalette.stone200,
    surfaceContainerHighest: AppPalette.stone300,
    onSurfaceVariant: AppPalette.stone700,
    outline: AppPalette.stone500,
    outlineVariant: AppPalette.stone300,
    shadow: AppPalette.navy950,
    scrim: AppPalette.navy950,
    inverseSurface: AppPalette.navy900,
    onInverseSurface: AppPalette.stone100,
    inversePrimary: AppPalette.azure300,
    surfaceTint: AppPalette.azure700,
  );

  static const ColorScheme _darkScheme = ColorScheme.dark(
    primary: AppPalette.azure300,
    onPrimary: AppPalette.azure950,
    primaryContainer: AppPalette.azure900,
    onPrimaryContainer: AppPalette.azure100,
    primaryFixed: AppPalette.azure100,
    primaryFixedDim: AppPalette.azure300,
    onPrimaryFixed: AppPalette.azure950,
    onPrimaryFixedVariant: AppPalette.azure800,
    secondary: AppPalette.stone200,
    onSecondary: AppPalette.navy900,
    secondaryContainer: AppPalette.navy700,
    onSecondaryContainer: AppPalette.stone100,
    secondaryFixed: AppPalette.stone100,
    secondaryFixedDim: AppPalette.stone300,
    onSecondaryFixed: AppPalette.navy950,
    onSecondaryFixedVariant: AppPalette.navy700,
    tertiary: AppPalette.brass200,
    onTertiary: AppPalette.navy950,
    tertiaryContainer: Color(0xFF503815),
    onTertiaryContainer: AppPalette.brass100,
    tertiaryFixed: AppPalette.brass100,
    tertiaryFixedDim: AppPalette.brass200,
    onTertiaryFixed: AppPalette.navy950,
    onTertiaryFixedVariant: AppPalette.brass700,
    error: AppPalette.red300,
    onError: Color(0xFF571713),
    errorContainer: Color(0xFF76241F),
    onErrorContainer: AppPalette.red100,
    surface: AppPalette.navy950,
    onSurface: AppPalette.stone100,
    surfaceDim: Color(0xFF030A14),
    surfaceBright: AppPalette.navy700,
    surfaceContainerLowest: Color(0xFF020811),
    surfaceContainerLow: Color(0xFF08152A),
    surfaceContainer: AppPalette.navy900,
    surfaceContainerHigh: AppPalette.navy800,
    surfaceContainerHighest: AppPalette.navy700,
    onSurfaceVariant: AppPalette.stone300,
    outline: AppPalette.stone500,
    outlineVariant: AppPalette.navy600,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppPalette.stone100,
    onInverseSurface: AppPalette.navy900,
    inversePrimary: AppPalette.azure700,
    surfaceTint: AppPalette.azure300,
  );

  static ThemeData _build(ColorScheme scheme, StatusColors statusColors) {
    final textTheme = _textTheme(scheme);
    final controlShape = RoundedRectangleBorder(borderRadius: AppRadius.small);
    final cardShape = RoundedRectangleBorder(
      borderRadius: AppRadius.large,
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.78)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFallback,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.04),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: <ThemeExtension<dynamic>>[statusColors],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withValues(alpha: 0.08),
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.low,
        centerTitle: false,
        toolbarHeight: 64,
        titleSpacing: AppSpace.lg,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: AppTypography.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withValues(alpha: 0.1),
        elevation: AppElevation.none,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppLayout.controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xl,
            vertical: AppSpace.md,
          ),
          shape: controlShape,
          elevation: AppElevation.none,
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppLayout.controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xl,
            vertical: AppSpace.md,
          ),
          shape: controlShape,
          elevation: AppElevation.low,
          shadowColor: scheme.shadow.withValues(alpha: 0.14),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, AppLayout.controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xl,
            vertical: AppSpace.md,
          ),
          shape: controlShape,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(AppLayout.minTouchTarget, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size.square(AppLayout.minTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: AppElevation.medium,
        focusElevation: AppElevation.medium,
        hoverElevation: AppElevation.high,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.lg,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.primary,
          fontWeight: AppTypography.semibold,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppRadius.small,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.small,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.small,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.small,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.small,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.small,
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.xs,
        ),
        minTileHeight: 56,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: AppTypography.semibold,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.72),
        space: 1,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withValues(alpha: 0.1),
        elevation: AppElevation.medium,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? AppTypography.bold : AppTypography.semibold,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            size: selected ? 24 : 22,
          );
        }),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: AppRadius.small),
        elevation: AppElevation.medium,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: AppTypography.semibold,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: AppTypography.bold,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppLayout.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpace.md),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : scheme.surfaceContainerLow;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant),
          ),
        ),
        selectedIcon: const Icon(Icons.check_rounded, size: 18),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: scheme.outline, width: 1.4),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.12);
          }
          return states.contains(WidgetState.selected) ? scheme.primary : null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: AppTypography.medium,
        ),
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: scheme.outlineVariant,
        overlayColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: 0.06),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.high,
        shadowColor: scheme.shadow.withValues(alpha: 0.18),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: AppSpace.xl,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.extraLarge),
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: scheme.onSurface,
          fontWeight: AppTypography.bold,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        modalBackgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.high,
        modalElevation: AppElevation.high,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: AppTypography.medium,
        ),
        actionTextColor: scheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: AppElevation.medium,
        insetPadding: const EdgeInsets.all(AppSpace.lg),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadius.small,
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
      ),
      dividerColor: scheme.outlineVariant,
      focusColor: scheme.primary.withValues(alpha: 0.12),
      hoverColor: scheme.primary.withValues(alpha: 0.06),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final theme =
        TextTheme(
          displayLarge: const TextStyle(
            fontSize: 56,
            height: 1.06,
            fontWeight: AppTypography.extraBold,
            letterSpacing: -2,
          ),
          displayMedium: const TextStyle(
            fontSize: 45,
            height: 1.08,
            fontWeight: AppTypography.extraBold,
            letterSpacing: -1.4,
          ),
          displaySmall: const TextStyle(
            fontSize: 36,
            height: 1.1,
            fontWeight: AppTypography.bold,
            letterSpacing: -1,
          ),
          headlineLarge: const TextStyle(
            fontSize: 32,
            height: AppTypography.titleHeight,
            fontWeight: AppTypography.bold,
            letterSpacing: -0.7,
          ),
          headlineMedium: const TextStyle(
            fontSize: 28,
            height: AppTypography.titleHeight,
            fontWeight: AppTypography.bold,
            letterSpacing: -0.5,
          ),
          headlineSmall: const TextStyle(
            fontSize: 24,
            height: 1.22,
            fontWeight: AppTypography.bold,
            letterSpacing: -0.35,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            height: 1.25,
            fontWeight: AppTypography.bold,
            letterSpacing: -0.2,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            height: 1.32,
            fontWeight: AppTypography.semibold,
          ),
          titleSmall: const TextStyle(
            fontSize: 14,
            height: 1.35,
            fontWeight: AppTypography.semibold,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            height: AppTypography.bodyHeight,
            fontWeight: AppTypography.regular,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: AppTypography.bodyHeight,
            fontWeight: AppTypography.regular,
          ),
          bodySmall: const TextStyle(
            fontSize: 12,
            height: 1.45,
            fontWeight: AppTypography.regular,
          ),
          labelLarge: const TextStyle(
            fontSize: 14,
            height: 1.25,
            fontWeight: AppTypography.bold,
            letterSpacing: 0.05,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            height: 1.25,
            fontWeight: AppTypography.semibold,
            letterSpacing: 0.1,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            height: 1.25,
            fontWeight: AppTypography.semibold,
            letterSpacing: 0.15,
          ),
        ).apply(
          fontFamily: AppTypography.fontFamily,
          fontFamilyFallback: AppTypography.fontFallback,
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );

    return theme;
  }
}
