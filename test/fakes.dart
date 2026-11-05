import 'package:railway_clean_ip_scanner/app/probe_engine.dart';
import 'package:railway_clean_ip_scanner/engine/vless_parser.dart';
import 'package:railway_clean_ip_scanner/engine/vless_scanner.dart';

/// Engine stand-in for controller and widget tests: no sockets.
class FakeEngine implements ProbeEngine {
  FakeEngine({
    this.scanResults = const <ScanResult>[],
    this.testOutcomes = const <String, ScanResult>{},
    this.resultsByDomain = const <String, List<ScanResult>>{},
  });

  /// Results the scan reports, in arrival order. Successes are kept sorted.
  final List<ScanResult> scanResults;

  /// Per-domain scan results (multi-config tests); falls back to
  /// [scanResults] for domains not listed here.
  final Map<String, List<ScanResult>> resultsByDomain;

  /// Every domain a scan was started for, in order.
  final List<String> scannedDomains = <String>[];

  /// Outcome per IP for "Test these".
  final Map<String, ScanResult> testOutcomes;

  int testCalls = 0;

  @override
  Future<List<ScanResult>> scan({
    required String subnetPrefix,
    required String domain,
    required String uuid,
    required String path,
    required int port,
    required void Function(int completed, int total, ScanResult result) onProgress,
    required bool Function() shouldStop,
    ScanAbort? abort,
  }) async {
    scannedDomains.add(domain);
    final source = resultsByDomain[domain] ?? scanResults;
    final kept = <ScanResult>[];
    var completed = 0;
    for (final r in source) {
      if (shouldStop()) {
        break;
      }
      completed++;
      if (r.isSuccess) {
        kept.add(r);
      }
      onProgress(completed, 254, r);
    }
    kept.sort((a, b) => a.delayMs.compareTo(b.delayMs));
    return kept;
  }

  @override
  Future<Map<String, ScanResult>> testIps({
    required List<String> ips,
    required VlessConfig config,
  }) async {
    testCalls++;
    return <String, ScanResult>{
      for (final ip in ips)
        ip: testOutcomes[ip] ?? ScanResult(ip, false, error: 'not in fake outcomes'),
    };
  }
}

ScanResult ok(String ip, int ms) => ScanResult(ip, true, delayMs: ms);

ScanResult dead(String ip) => ScanResult(ip, false, error: 'fake dead');

const String sampleLink =
    'vless://11111111-2222-3333-4444-555555555555@fast-a.up.railway.app:443'
    '?encryption=none&security=tls&sni=fast-a.up.railway.app&type=ws'
    '&host=fast-a.up.railway.app&path=%2Fws#My%20Railway%20Config';
