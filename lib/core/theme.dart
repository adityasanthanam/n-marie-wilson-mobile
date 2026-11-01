import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Brand tokens from the web's src/styles.css.
class Brand {
  static const paper = Color(0xFFFAFAFA);
  static const ink = Color(0xFF09090B);
  static const red = Color(0xFFDC2626);
  static const gold = Color(0xFFFBBF24);
  static const goldDeep = Color(0xFFA16207);
  static const civicDeep = Color(0xFF360705);
  static const civicWarm = Color(0xFF631E05);
  static const heroBg = Color(0xFFFDF9F2);
  static const muted = Color(0xFF737373);
  static const border = Color(0xFFE5E5E5);
  static const online = Color(0xFF059669);
}

ThemeData buildTheme({required bool tamil, Brightness brightness = Brightness.light, bool googleFonts = true}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.red,
    primary: Brand.red,
    brightness: brightness,
    surface: brightness == Brightness.light ? Colors.white : const Color(0xFF18181B),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  // Outfit for Latin, Noto Sans Tamil first when the UI is in Tamil (as on the web).
  final text = !googleFonts
      ? base.textTheme
      : tamil
          ? GoogleFonts.notoSansTamilTextTheme(base.textTheme)
          : GoogleFonts.outfitTextTheme(base.textTheme);
  final radius = BorderRadius.circular(10);
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: brightness == Brightness.light ? Brand.paper : const Color(0xFF09090B),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0.5,
      backgroundColor: brightness == Brightness.light ? Colors.white : const Color(0xFF09090B),
      titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) {
        final ios = Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.macOS;
        return Icon(ios ? Icons.arrow_back_ios_new : Icons.arrow_back, size: ios ? 20 : 24);
      },
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Brand.border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light ? const Color(0xFFFAFAFA) : const Color(0xFF27272A),
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: Brand.border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: Brand.border)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: radius)),
    ),
    // Native-feeling page transitions on each platform (swipe-back on iOS).
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    }),
  );
}
