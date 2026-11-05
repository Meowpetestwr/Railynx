// Local TLS + WebSocket mock, the Dart twin of tests/mock_server.py.
// It answers the probe's upgrade with 101, reads the masked VLESS frame, then
// answers according to [MockMode]. Test-only: bound to 127.0.0.1, with the
// self-signed certificate in test/fixtures/.

import 'dart:async';
import 'dart:io';

enum MockMode {
  /// 101, then "HTTP/1.1 204 No Content": a clean IP.
  success204,

  /// 101, then "HTTP/1.1 200 OK": reachable but not clean.
  wrong200,

  /// "HTTP/1.1 400": the upgrade is refused.
  upgradeRefused,

  /// Closes right after the TLS handshake, before any reply.
  closeBeforeUpgrade,
}

class MockVlessServer {
  MockVlessServer(this.mode);

  final MockMode mode;
  SecureServerSocket? _server;
  StreamSubscription<SecureSocket>? _accepting;

  /// Number of probes that were answered with a 204.
  int accepted = 0;

  int get port => _server!.port;

  static SecurityContext _context() {
    return SecurityContext()
      ..useCertificateChain('test/fixtures/mock_cert.pem')
      ..usePrivateKey('test/fixtures/mock_key.pem');
  }

  Future<void> start() async {
    _server = await SecureServerSocket.bind(InternetAddress.loopbackIPv4, 0, _context());
    _accepting = _server!.listen(_handle);
  }

  Future<void> close() async {
    await _accepting?.cancel();
    await _server?.close();
  }

  void _handle(SecureSocket client) {
    final pending = BytesBuilder(copy: false);
    var upgraded = false;
    StreamSubscription<List<int>>? sub;
    sub = client.listen(
      (List<int> data) async {
        if (!upgraded) {
          pending.add(data);
          final text = String.fromCharCodes(pending.toBytes());
          if (!text.contains('\r\n\r\n')) {
            return;
          }
          upgraded = true;
          if (mode == MockMode.closeBeforeUpgrade) {
            client.destroy();
            return;
          }
          if (mode == MockMode.upgradeRefused) {
            client.add('HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n'.codeUnits);
            await client.flush();
            client.destroy();
            return;
          }
          client.add(
            'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n'
                'Connection: Upgrade\r\n\r\n'
                .codeUnits,
          );
          await client.flush();
          return;
        }
        // The masked VLESS frame arrived: answer, then close.
        final success = mode == MockMode.success204;
        final reply = success
            ? 'HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n'
            : 'HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n';
        client.add(reply.codeUnits);
        await client.flush();
        if (success) {
          accepted++;
        }
        await sub?.cancel();
        client.destroy();
      },
      onError: (Object _) {},
      cancelOnError: true,
    );
  }
}
