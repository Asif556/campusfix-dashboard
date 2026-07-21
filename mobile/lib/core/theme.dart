import 'package:flutter/material.dart';

/// Color system ported 1:1 from the web app's `index.css` HSL custom properties,
/// so the mobile UI reads as the same product. Light values are the primary
/// design; dark values follow the web app's `.dark` block.
Color _hsl(double h, double s, double l) =>
    HSLColor.fromAHSL(1, h, s / 100, l / 100).toColor();

class AppColors {
  AppColors._();

  // ── Light ──────────────────────────────────────────────────────────────
  static final background = _hsl(214, 32, 97);
  static final foreground = _hsl(224, 71, 10);
  static final card = _hsl(0, 0, 100);
  static final cardForeground = _hsl(224, 71, 10);
  static final primary = _hsl(224, 69, 33);
  static final primaryForeground = _hsl(210, 40, 98);
  static final secondary = _hsl(217, 91, 60);
  static final muted = _hsl(214, 32, 94);
  static final mutedForeground = _hsl(215, 16, 47);
  static final border = _hsl(214, 20, 90);
  static final destructive = _hsl(0, 84, 60);
  static final ring = _hsl(224, 69, 33);

  // ── Dark ───────────────────────────────────────────────────────────────
  static final backgroundDark = _hsl(222, 47, 6);
  static final foregroundDark = _hsl(210, 40, 98);
  static final cardDark = _hsl(222, 47, 9);
  static final primaryDark = _hsl(217, 91, 60);
  static final mutedDark = _hsl(217, 33, 17);
  static final mutedForegroundDark = _hsl(215, 20, 65);
  static final borderDark = _hsl(217, 33, 17);

  // ── Status colors ──────────────────────────────────────────────────────
  static final statusSubmitted = _hsl(45, 93, 47); // amber/gold
  static final statusAssigned = _hsl(217, 91, 60); // blue
  static final statusProgress = _hsl(25, 95, 53); // orange
  static final statusCompleted = _hsl(152, 69, 41); // green
  static final statusPending = _hsl(38, 92, 50); // amber-500
  static final statusReopened = _hsl(0, 84, 60); // red-500
  static final statusRejected = _hsl(350, 89, 60); // rose-500

  // ── Gradients ──────────────────────────────────────────────────────────
  static final gradientPrimary = [_hsl(224, 69, 33), _hsl(217, 91, 60)];
  static final gradientHero = [
    _hsl(224, 69, 28),
    _hsl(217, 91, 50),
    _hsl(199, 89, 48),
  ];

  /// Presentation for a complaint status (used by the status badge).
  static Color statusColor(String status) {
    switch (status) {
      case 'Submitted':
        return statusSubmitted;
      case 'Assigned':
        return statusAssigned;
      case 'In Progress':
        return statusProgress;
      case 'Completed':
        return statusCompleted;
      case 'Pending Acceptance':
        return statusPending;
      case 'Reopened':
        return statusReopened;
      case 'Rejected':
        return statusRejected;
      default:
        return statusSubmitted;
    }
  }
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.foreground,
      error: AppColors.destructive,
      onError: Colors.white,
    );
    return _base(scheme, AppColors.background, AppColors.mutedForeground);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      primary: AppColors.primaryDark,
      onPrimary: AppColors.foregroundDark,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: AppColors.cardDark,
      onSurface: AppColors.foregroundDark,
      error: AppColors.destructive,
      onError: Colors.white,
    );
    return _base(scheme, AppColors.backgroundDark, AppColors.mutedForegroundDark);
  }

  static ThemeData _base(ColorScheme scheme, Color bg, Color mutedFg) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: mutedFg, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.brightness == Brightness.dark
                ? AppColors.borderDark
                : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.brightness == Brightness.dark
            ? AppColors.borderDark
            : AppColors.border,
        thickness: 1,
      ),
    );
  }
}
