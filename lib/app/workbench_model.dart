import '../engine/vless_parser.dart';
import '../engine/vless_scanner.dart';

/// Workbench rules from ui.html, kept free of widgets so they can be tested.
const int genMin = 1;
const int genMax = 20;
const int defaultGenCount = 5;
const List<String> modeOrder = <String>['top', 'best', 'custom'];

const Map<String, String> modeExplainer = <String, String>{
  'top': 'Each config gets the next-best IP.',
  'best': 'Every config uses the fastest IP.',
  'custom': 'Pick the IP for each config yourself.',
};

/// One assigned row. [ip] is null when there are no results yet.
/// [configIndex] identifies the pasted config the row belongs to
/// (multi-config mode); it is 0 in the single-config flow.
class ConfigRow {
  const ConfigRow({this.ip, this.changed = false, this.stale = false, this.configIndex = 0});

  final String? ip;
  final bool changed;
  final bool stale;
  final int configIndex;
}

/// A "Test these" measurement for one IP.
class Tested {
  const Tested({this.delayMs, this.delta = 0, this.dead = false});

  final int? delayMs;
  final int delta;
  final bool dead;

  Tested withoutDelta() => Tested(delayMs: delayMs, delta: 0, dead: dead);
}

enum ChipKind { measuring, dead, stale, latency }

/// What the latency cell of a row shows.
class ChipInfo {
  const ChipInfo(this.kind, {this.ms, this.delta = 0});

  final ChipKind kind;
  final int? ms;
  final int delta;
}

class WorkbenchModel {
  WorkbenchModel._();

  static Map<String, int> delayByIp(List<ScanResult> results) {
    return <String, int>{for (final r in results) r.ip: r.delayMs};
  }

  static List<ConfigRow> assignments({
    required int count,
    required String mode,
    required List<ScanResult> results,
    required Map<int, String> custom,
  }) {
    final delays = delayByIp(results);
    final rows = <ConfigRow>[];
    for (var i = 0; i < count; i++) {
      final auto = results.isEmpty ? null : results[i % results.length].ip;
      if (mode == 'best') {
        rows.add(ConfigRow(ip: results.isEmpty ? null : results.first.ip));
      } else if (mode == 'custom' && custom[i] != null) {
        final pick = custom[i]!;
        rows.add(ConfigRow(
          ip: pick,
          changed: pick != auto,
          stale: !delays.containsKey(pick),
        ));
      } else {
        rows.add(ConfigRow(ip: auto));
      }
    }
    return rows;
  }

  /// Multi-config rows: one row per pasted config, assigned from ITS OWN
  /// server's results (configs that share a server share that server's
  /// result list, Top N rotating within the group by the config's
  /// position in it). Mirrors [assignments] rule for rule.
  static List<ConfigRow> assignmentsMulti({
    required List<VlessConfig> configs,
    required Map<String, List<ScanResult>> resultsByGroup,
    required String Function(VlessConfig) groupKey,
    required String mode,
    required Map<int, String> custom,
  }) {
    final seenInGroup = <String, int>{};
    final rows = <ConfigRow>[];
    for (var j = 0; j < configs.length; j++) {
      final key = groupKey(configs[j]);
      final results = resultsByGroup[key] ?? const <ScanResult>[];
      final pos = seenInGroup[key] ?? 0;
      seenInGroup[key] = pos + 1;
      final delays = delayByIp(results);
      final auto = results.isEmpty ? null : results[pos % results.length].ip;
      if (mode == 'best') {
        rows.add(ConfigRow(ip: results.isEmpty ? null : results.first.ip, configIndex: j));
      } else if (mode == 'custom' && custom[j] != null) {
        final pick = custom[j]!;
        rows.add(ConfigRow(
          ip: pick,
          changed: pick != auto,
          stale: !delays.containsKey(pick),
          configIndex: j,
        ));
      } else {
        rows.add(ConfigRow(ip: auto, configIndex: j));
      }
    }
    return rows;
  }

  /// Ran out of distinct IPs (any mode except Best-for-all): configs share.
  static bool shortage({
    required String mode,
    required int count,
    required int resultCount,
  }) {
    return mode != 'best' && resultCount > 0 && count > resultCount;
  }

  static String shortageText(int resultCount) {
    final plural = resultCount == 1 ? '' : 's';
    return 'Only $resultCount clean IP$plural found, so some configs will share one.';
  }

  static List<String> uniqueIps(List<ConfigRow> rows) {
    final seen = <String>{};
    final out = <String>[];
    for (final row in rows) {
      final ip = row.ip;
      if (ip != null && seen.add(ip)) {
        out.add(ip);
      }
    }
    return out;
  }

  /// Previous delay for the delta badge: the last good test, else the scan.
  static int? previousDelay(String ip, Map<String, Tested> tested, Map<String, int> delays) {
    final t = tested[ip];
    if (t != null && !t.dead) {
      return t.delayMs;
    }
    return delays[ip];
  }

  static Tested measured(int? previous, int newDelayMs) {
    final delta = previous == null ? 0 : previous - newDelayMs;
    return Tested(delayMs: newDelayMs, delta: delta, dead: false);
  }

  static String deltaLabel(int delta) {
    return delta > 0 ? '↓$delta' : '↑${-delta}';
  }

  static ChipInfo chipFor({
    required String? ip,
    required Map<String, Tested> tested,
    required Map<String, int> delays,
    required Set<String> testingIps,
    required bool testing,
  }) {
    if (ip == null) {
      return const ChipInfo(ChipKind.stale);
    }
    if (testing && testingIps.contains(ip)) {
      return const ChipInfo(ChipKind.measuring);
    }
    final t = tested[ip];
    if (t != null) {
      if (t.dead) {
        return const ChipInfo(ChipKind.dead);
      }
      return ChipInfo(ChipKind.latency, ms: t.delayMs, delta: t.delta);
    }
    final delay = delays[ip];
    if (delay == null) {
      return const ChipInfo(ChipKind.stale);
    }
    return ChipInfo(ChipKind.latency, ms: delay);
  }
}
