import 'dart:ui';
import 'package:flutter/material.dart';

enum FleetTheme { transitObsidian, daylightYard, roadside }

class AppTheme {
  static ThemeData data(FleetTheme mode) {
    final dark = mode != FleetTheme.daylightYard;
    final high = mode == FleetTheme.roadside;
    final bg = mode == FleetTheme.daylightYard
        ? const Color(0xffedf4f2) : high ? const Color(0xff080b0e) : const Color(0xff101820);
    final accent = high ? const Color(0xffffc247) : const Color(0xff55d6e8);
    return ThemeData(
      useMaterial3: true, brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: dark ? Brightness.dark : Brightness.light,
        surface: dark ? const Color(0xff1b2730) : Colors.white),
      appBarTheme: AppBarTheme(backgroundColor: bg, foregroundColor: dark ? Colors.white : const Color(0xff17252a)),
      cardTheme: CardThemeData(color: dark ? const Color(0xff1c2933).withValues(alpha: .82) : Colors.white.withValues(alpha: .86),
        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: dark ? Colors.white.withValues(alpha: .10) : Colors.black.withValues(alpha: .07)))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: dark ? Colors.white.withValues(alpha: .06) : Colors.black.withValues(alpha: .035),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  static Widget glass({required Widget child, EdgeInsets padding = const EdgeInsets.all(18), double radius = 22}) =>
    ClipRRect(borderRadius: BorderRadius.circular(radius), child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(padding: padding,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .065),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: .13))),
        child: child)));
}
