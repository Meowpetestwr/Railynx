// Golden tests for the VLESS header, HTTP payload, WebSocket frame and
// upgrade request. Bytes were produced by scanner.py.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:railway_clean_ip_scanner/engine/vless_scanner.dart';
import 'package:test/test.dart';

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> _unhex(String hex) => <int>[
      for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
    ];

Map<String, dynamic> _golden() {
  final text = File('test/golden/binary.json').readAsStringSync();
  return jsonDecode(text) as Map<String, dynamic>;
}

void main() {
  final golden = _golden();

  test('vless header bytes match scanner.py', () {
    for (final raw in golden['vless_header'] as List<dynamic>) {
      final c = raw as Map<String, dynamic>;
      expect(_hex(buildVlessHeader(c['uuid'] as String)), equals(c['hex']));
    }
  });

  test('http payload matches scanner.py', () {
    expect(_hex(buildHttpPayload()), equals(golden['http_payload_hex']));
  });

  test('full vless data matches scanner.py', () {
    const uuid = '11111111-2222-3333-4444-555555555555';
    expect(_hex(buildFullVlessData(uuid)), equals(golden['full_data_hex']));
  });

  test('ws frames match scanner.py (short, 126+ length, empty)', () {
    for (final raw in golden['ws_frame'] as List<dynamic>) {
      final c = raw as Map<String, dynamic>;
      final data = _unhex(c['data_hex'] as String);
      expect(_hex(buildWsFrame(data)), equals(c['hex']));
    }
  });

  test('ws upgrade request matches scanner.py', () {
    for (final raw in golden['ws_upgrade'] as List<dynamic>) {
      final c = raw as Map<String, dynamic>;
      expect(_hex(buildWsUpgradeRequest(c['domain'] as String, c['path'] as String)),
          equals(c['hex']));
    }
  });

  test('uuid with braces and urn prefix is accepted like Python UUID()', () {
    const plain = '11111111-2222-3333-4444-555555555555';
    expect(uuidBytes('{$plain}'), equals(uuidBytes(plain)));
    expect(uuidBytes('urn:uuid:$plain'), equals(uuidBytes(plain)));
  });

  test('bad uuid throws (probe turns it into a failed ScanResult)', () {
    expect(() => uuidBytes('not-a-uuid'), throwsFormatException);
  });

  test('has204 detects both signatures and ignores others', () {
    expect(has204(latin1.encode('HTTP/1.1 204 No Content\r\n')), isTrue);
    expect(has204(latin1.encode('HTTP/1.0 204 No Content')), isTrue);
    expect(has204(latin1.encode('HTTP/1.1 200 OK')), isFalse);
    expect(has204(<int>[]), isFalse);
  });

  test('ws frame of 200 bytes uses the 126 extended length', () {
    final frame = buildWsFrame(Uint8List(200));
    expect(frame[0], 0x82);
    expect(frame[1], 0x80 | 126);
    expect(frame[2], 0);
    expect(frame[3], 200);
    expect(frame.length, 4 + 4 + 200);
  });
}
