import '../engine/vless_parser.dart';
import '../engine/vless_scanner.dart';

/// The network side of the app, behind an interface so widget tests can
/// replace it with a fake. [RealProbeEngine] is the only production code.
abstract class ProbeEngine {
  Future<List<ScanResult>> scan({
    required String subnetPrefix,
    required String domain,
    required String uuid,
    required String path,
    required int port,
    required void Function(int completed, int total, ScanResult result) onProgress,
    required bool Function() shouldStop,
    ScanAbort? abort,
  });

  Future<Map<String, ScanResult>> testIps({
    required List<String> ips,
    required VlessConfig config,
  });
}

class RealProbeEngine implements ProbeEngine {
  static const int testConcurrency = 8;

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
  }) {
    return scanSubnet(
      subnetPrefix: subnetPrefix,
      domain: domain,
      uuid: uuid,
      path: path,
      port: port,
      onProgress: onProgress,
      shouldStop: shouldStop,
      abort: abort,
    );
  }

  @override
  Future<Map<String, ScanResult>> testIps({
    required List<String> ips,
    required VlessConfig config,
  }) async {
    final out = <String, ScanResult>{};
    final queue = List<String>.of(ips);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final ip = queue.removeAt(0);
        out[ip] = await testIpRealDelay(
          ip,
          config.domain,
          config.uuid,
          path: config.path.isEmpty ? '/' : config.path,
          port: config.port,
          doubleCheck: true,
        );
      }
    }

    final workers = ips.length < testConcurrency ? ips.length : testConcurrency;
    await Future.wait(<Future<void>>[for (var i = 0; i < workers; i++) worker()]);
    return out;
  }
}
