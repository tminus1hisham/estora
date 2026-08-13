import 'package:flutter/material.dart';

/// Brand colours for the tenant experience.
///
/// Navy gives financial screens authority, warm stone keeps large surfaces
/// comfortable, and the azure ramp — deep navy blue through sky — marks
/// interactive states.
abstract final class AppPalette {
  // Navy — the dark neutral the brand is grounded in.
  static const Color navy950 = Color(0xFF050E1C);
  static const Color navy900 = Color(0xFF0A1A30);
  static const Color navy800 = Color(0xFF142B4C);
  static const Color navy700 = Color(0xFF26426B);
  static const Color navy600 = Color(0xFF3C567F);

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

  // Azure — navy blue at the dark end, sky blue at the light end.
  //
  // One ramp rather than two: light mode takes its primary from the navy end
  // so buttons read as authoritative on cream, and dark mode takes its primary
  // from the sky end so the same role stays legible on a navy ground.
  static const Color azure950 = Color(0xFF04203F);
  static const Color azure900 = Color(0xFF072F5E);
  static const Color azure800 = Color(0xFF0A3D7C);
  static const Color azure700 = Color(0xFF104B93);
  static const Color azure600 = Color(0xFF1660B0);
  static const Color azure500 = Color(0xFF2078CE);
  static const Color azure300 = Color(0xFF7EC2F5);
  static const Color azure200 = Color(0xFFB2DBFA);
  static const Color azure100 = Color(0xFFDCEDFD);
  static const Color azure50 = Color(0xFFEFF7FE);

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
  // Green carries "paid" and "active" on its own now that the brand ramp is
  // blue — a status badge in the brand colour would read as a control.
  static const Color green700 = Color(0xFF1A6E47);
  static const Color green300 = Color(0xFF6FD3A2);
  // Steel blue for work in flight. Deliberately cooler and lighter than
  // [azure700] so a PENDING badge does not read as a primary action.
  static const Color blue700 = Color(0xFF1F6E9C);
  static const Color blue300 = Color(0xFF8FCEF0);
  static const Color violet700 = Color(0xFF61558F);
  static const Color violet300 = Color(0xFFC2B8EE);
}
