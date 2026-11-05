// Live probe tests against the local mock server: real sockets, real TLS,
// real WebSocket upgrade and the real VLESS frame. Loopback only.

import 'dart:io';

import 'package:railway_clean_ip_scanner/engine/vless_scanner.dart';
import 'package:test/test.dart';

import 'mock_vless_server.dart';

const String uuid = '11111111-2222-3333-4444-555555555555';
const String domain = 'localhost';

void main() {
  group('probe against the mock (success path)', () {
    test('TLS, 101 and HTTP 204 make a clean IP', () async {
      final mock = MockVlessServer(MockMode.success204);
      await mock.start();
      addTearDown(mock.close);

      final r = await runSingleProbe('127.0.0.1', domain, uuid, port: mock.port);

      expect(r.isSuccess, isTrue, reason: 'error: ${r.error}');
      expect(r.error, isNull);
      expect(r.delayMs, greaterThanOrEqualTo(0));
      expect(mock.accepted, 1);
    });

    test('three confirmed probes give one averaged clean result', () async {
      final mock = MockVlessServer(MockMode.success204);
      await mock.start();
      addTearDown(mock.close);

      final r = await testIpRealDelay('127.0.0.1', domain, uuid, port: mock.port);

      expect(r.isSuccess, isTrue, reason: 'error: ${r.error}');
      expect(mock.accepted, 3);
    });

    test('doubleCheck off runs a single probe', () async {
      final mock = MockVlessServer(MockMode.success204);
      await mock.start();
      addTearDown(mock.close);

      final r = await testIpRealDelay(
        '127.0.0.1', domain, uuid, port: mock.port, doubleCheck: false);

      expect(r.isSuccess, isTrue, reason: 'error: ${r.error}');
      expect(mock.accepted, 1);
    });
  });

  group('probe against the mock (failure paths)', () {
    test('a 200 instead of 204 is not clean', () async {
      final mock = MockVlessServer(MockMode.wrong200);
      await mock.start();
      addTearDown(mock.close);

      final r = await runSingleProbe('127.0.0.1', domain, uuid, port: mock.port);

      expect(r.isSuccess, isFalse);
      expect(r.error, 'No valid Google 204 response');
      expect(mock.accepted, 0);
    });

    test('a refused upgrade reports the status line', () async {
      final mock = MockVlessServer(MockMode.upgradeRefused);
      await mock.start();
      addTearDown(mock.close);

      final r = await runSingleProbe('127.0.0.1', domain, uuid, port: mock.port);

      expect(r.isSuccess, isFalse);
      expect(r.error, startsWith('WS Upgrade failed: HTTP/1.1 400'));
    });

    test('a connection closed before any reply is not clean', () async {
      final mock = MockVlessServer(MockMode.closeBeforeUpgrade);
      await mock.start();
      addTearDown(mock.close);

      final r = await runSingleProbe('127.0.0.1', domain, uuid, port: mock.port);

      expect(r.isSuccess, isFalse);
      expect(r.error, isNotNull);
    });

    test('a closed port fails with an error, not an exception', () async {
      // Bind to get a free port, then release it so nothing listens there.
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();

      final r = await runSingleProbe('127.0.0.1', domain, uuid, port: port);

      expect(r.isSuccess, isFalse);
      expect(r.error, isNotNull);
    });

    test('a failing first probe stops the three-probe check', () async {
      final mock = MockVlessServer(MockMode.wrong200);
      await mock.start();
      addTearDown(mock.close);

      final r = await testIpRealDelay('127.0.0.1', domain, uuid, port: mock.port);

      expect(r.isSuccess, isFalse);
      expect(r.error, 'No valid Google 204 response');
    });

    test('a bad UUID fails the probe cleanly', () async {
      final mock = MockVlessServer(MockMode.success204);
      await mock.start();
      addTearDown(mock.close);

      final r = await runSingleProbe('127.0.0.1', domain, 'not-a-uuid', port: mock.port);

      expect(r.isSuccess, isFalse);
      expect(r.error, isNotNull);
    });
  });
}
