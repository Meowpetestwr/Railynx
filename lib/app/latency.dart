import 'package:flutter/material.dart';

import 'tokens.dart';

/// Latency tiers from ui.html: fast <120, mid 120-300, slow 300-600, poor >600.
enum LatencyTier { fast, mid, slow, poor }

LatencyTier tierFor(int ms) {
  if (ms < 120) {
    return LatencyTier.fast;
  }
  if (ms < 300) {
    return LatencyTier.mid;
  }
  if (ms <= 600) {
    return LatencyTier.slow;
  }
  return LatencyTier.poor;
}

Color tierColor(LatencyTier tier) {
  switch (tier) {
    case LatencyTier.fast:
      return Tokens.fast;
    case LatencyTier.mid:
      return Tokens.mid;
    case LatencyTier.slow:
      return Tokens.slow;
    case LatencyTier.poor:
      return Tokens.poor;
  }
}

/// Width fraction of the result bar: max(6, 100 * (1 - min(ms, 700) / 700)) percent.
double barFraction(int ms) {
  final pct = 100 * (1 - (ms < 700 ? ms : 700) / 700);
  final clamped = pct < 6 ? 6.0 : pct;
  return clamped / 100;
}
