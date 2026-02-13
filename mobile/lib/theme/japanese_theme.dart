import 'package:flutter/material.dart';

/// Japanese Miyabi Aesthetic Color Palette
/// Traditional colors inspired by Japanese culture
class JapaneseColors {
  // Primary Traditional Colors
  static const Color kogane = Color(0xFFE6B422);        // Gold (Kogane-iro)
  static const Color wakatake = Color(0xFF68BE8D);      // Young Bamboo Green
  static const Color sakura = Color(0xFFFEF4F4);        // Cherry Blossom White
  static const Color sumi = Color(0xFF1C1C1C);          // Ink Black
  static const Color shironeri = Color(0xFFFCFAF2);     // Off-white (Paper)
  
  // Pin Attribute Colors
  static const Color mikanOrange = Color(0xFFFF8C42);   // Mikan Orange (Agriculture)
  static const Color lanternRed = Color(0xFFE63946);    // Traditional Lantern Red (Heritage)
  static const Color sakuraPink = Color(0xFFFFB7C5);    // Sakura Pink (Nature)
  static const Color yumeMurasaki = Color(0xFF9D84B7);  // Dream Purple (Sensation)
  
  // UI Accent Colors
  static const Color bambooGreen = Color(0xFF4A7C59);   // Dark Bamboo
  static const Color teaGreen = Color(0xFFA8C7A4);      // Matcha Green
  static const Color cloudGray = Color(0xFFE8E8E8);     // Cloud Gray
}

/// Japanese Miyabi Theme Data
/// Applies traditional Japanese aesthetic to the entire app
ThemeData get japaneseMiyabiTheme => ThemeData(
  // Primary colors
  primaryColor: JapaneseColors.wakatake,
  scaffoldBackgroundColor: JapaneseColors.shironeri,
  
  // Color scheme
  colorScheme: ColorScheme.light(
    primary: JapaneseColors.wakatake,
    secondary: JapaneseColors.kogane,
    surface: Colors.white,
    error: JapaneseColors.lanternRed,
    onPrimary: Colors.white,
    onSecondary: JapaneseColors.sumi,
    onSurface: JapaneseColors.sumi,
    onError: Colors.white,
  ),
  
  // Typography
  fontFamily: 'NotoSansJP',
  textTheme: TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: JapaneseColors.sumi,
      fontFamily: 'NotoSansJP',
    ),
    displayMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: JapaneseColors.sumi,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: JapaneseColors.sumi,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: JapaneseColors.sumi,
    ),
  ),
  
  // Card theme (rounded, soft shadows)
  cardTheme: CardThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 2,
    color: Colors.white,
    shadowColor: Colors.black12,
  ),
  
  // App bar theme
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: JapaneseColors.sumi,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: JapaneseColors.sumi,
      fontFamily: 'NotoSansJP',
    ),
  ),
  
  // Floating action button
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: JapaneseColors.wakatake,
    foregroundColor: Colors.white,
    elevation: 4,
  ),
  
  // Bottom navigation bar
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: JapaneseColors.wakatake,
    unselectedItemColor: Colors.grey[400],
    elevation: 8,
    type: BottomNavigationBarType.fixed,
  ),
  
  // Input decoration
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: JapaneseColors.sakura,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: JapaneseColors.cloudGray),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: JapaneseColors.wakatake, width: 2),
    ),
  ),
  
  // Button theme
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: JapaneseColors.wakatake,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
  ),
  
  // Chip theme
  chipTheme: ChipThemeData(
    backgroundColor: JapaneseColors.sakura,
    labelStyle: TextStyle(color: JapaneseColors.sumi),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
);

/// Helper to get icon for pin attribute
IconData getPinAttributeIcon(String? attribute) {
  switch (attribute) {
    case 'agriculture':
      return Icons.agriculture;  // Or use custom mikan icon
    case 'heritage':
      return Icons.temple_buddhist;  // Or use custom lantern icon
    case 'nature':
      return Icons.park;
    case 'sensation':
      return Icons.auto_awesome;
    default:
      return Icons.place;
  }
}

/// Helper to get color for pin attribute
Color getPinAttributeColor(String? attribute) {
  switch (attribute) {
    case 'agriculture':
      return JapaneseColors.mikanOrange;
    case 'heritage':
      return JapaneseColors.lanternRed;
    case 'nature':
      return JapaneseColors.sakuraPink;
    case 'sensation':
      return JapaneseColors.yumeMurasaki;
    default:
      return JapaneseColors.wakatake;
  }
}
