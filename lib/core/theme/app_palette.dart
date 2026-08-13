import 'package:flutter/material.dart';

/// Brand colours for the tenant experience.
///
/// Ink gives financial screens authority, warm stone keeps large surfaces
/// comfortable, and emerald marks interactive and successful states.
abstract final class AppPalette {
  // Ink
  static const Color ink950 = Color(0xFF071512);
  static const Color ink900 = Color(0xFF0D211D);
  static const Color ink800 = Color(0xFF17332D);
  static const Color ink700 = Color(0xFF294942);
  static const Color ink600 = Color(0xFF3D5C55);

  // Warm stone
  static const Color stone0 = Color(0xFFFFFEFB);
  static const Color stone50 = Color(0xFFFAF8F3);
  static const Color stone100 = Color(0xFFF3F0E9);
  static const Color stone200 = Color(0xFFE7E2D8);
  static const Color stone300 = Color(0xFFD3CDC1);
  static const Color stone400 = Color(0xFFA9A79F);
  static const Color stone500 = Color(0xFF777B76);
  static const Color stone600 = Color(0xFF5C635E);
  static const Color stone700 = Color(0xFF414B46);

  // Emerald
  static const Color emerald950 = Color(0xFF032C23);
  static const Color emerald900 = Color(0xFF064535);
  static const Color emerald800 = Color(0xFF075B45);
  static const Color emerald700 = Color(0xFF087057);
  static const Color emerald600 = Color(0xFF0B8062);
  static const Color emerald500 = Color(0xFF159775);
  static const Color emerald300 = Color(0xFF69D3AD);
  static const Color emerald200 = Color(0xFFA5E7CE);
  static const Color emerald100 = Color(0xFFD9F5EA);
  static const Color emerald50 = Color(0xFFECFBF5);

  // A restrained warm accent for deadlines and premium highlights.
  static const Color brass700 = Color(0xFF8B5D16);
  static const Color brass500 = Color(0xFFB9842E);
  static const Color brass300 = Color(0xFFD6B477);
  static const Color brass200 = Color(0xFFEBCB8F);
  static const Color brass100 = Color(0xFFF8E9C9);

  // Semantic colours.
  static const Color red700 = Color(0xFFA93832);
  static const Color red300 = Color(0xFFF09B94);
  static const Color red100 = Color(0xFFFFE3E0);
  static const Color blue700 = Color(0xFF2B5F91);
  static const Color blue300 = Color(0xFF8EC4F1);
  static const Color violet700 = Color(0xFF61558F);
  static const Color violet300 = Color(0xFFC2B8EE);
}
