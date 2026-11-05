import 'package:flutter/material.dart';

/// Design tokens copied 1:1 from the Shafaq HTML mockup (:root + rules).
abstract final class Tokens {
  static const bg = Color(0xFF06081A);
  static const pageBehind = Color(0xFF020310);
  static const surface = Color(0xFF0D1426);
  static const ink = Color(0xFFF2F6FF);
  static const ink2 = Color(0xFFA9B8D8);
  static const ink3 = Color(0xFF7E8DB0);
  static const teal = Color(0xFF2DD4BF);
  static const indigo = Color(0xFF818CF8);
  static const pink = Color(0xFFF472B6);
  static const sky = Color(0xFF38BDF8);
  static const amber = Color(0xFFFBBF77);
  static const fast = Color(0xFF34E3B0);
  static const mid = Color(0xFF7DD3FC);
  static const slow = Color(0xFFF5C26B);
  static const poor = Color(0xFFF2778C);
  static const onGradient = Color(0xFF080A1C);
  static const crownInk = Color(0xFF06241D);
  static const placeholder = Color(0xFF55627F);

  /// --edge: rgba(170,195,235,.14)
  static const edge = Color(0xFFAAC3EB);

  /// .glass fill: linear-gradient(160deg, rgba(148,175,220,.10), rgba(148,175,220,.03))
  static const glassSheen = Color(0xFF94AFDC);

  /// input background: rgba(6,8,26,.6)
  static const inputBg = Color(0x9906081A);

  /// input border: rgba(170,195,235,.16)
  static const inputEdge = Color(0x29AAC3EB);

  /// toast: rgba(236,242,255,.96) on #0a0d22
  static const toastBg = Color(0xF5ECF2FF);
  static const toastInk = Color(0xFF0A0D22);

  /// .btn-grad / --grad: linear-gradient(120deg, teal 0%, indigo 42%, pink 78%, amber 100%)
  static const LinearGradient grad = LinearGradient(
    begin: Alignment(-1, -0.35),
    end: Alignment(1, 0.35),
    colors: <Color>[teal, indigo, pink, amber],
    stops: <double>[0, 0.42, 0.78, 1],
  );

  /// Ring stroke gradient stops from the mockup's #gradStroke.
  static const List<Color> ringColors = <Color>[teal, indigo, pink, amber];
  static const List<double> ringStops = <double>[0, 0.42, 0.80, 1];

  static const String uiFont = 'Manrope';
  static const String monoFont = 'JetBrains Mono';
}
