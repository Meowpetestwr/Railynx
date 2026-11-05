// Scanner engine — pure Dart port of scanner.py (behaviour-identical).
//
// Probe, per candidate IP:
//   1. TCP connect to IP:port, timeout 2400 ms
//   2. TLS handshake with SNI = domain, ALPN http/1.1, trust-all certificates
//   3. WebSocket upgrade GET <path>; the status line must contain "101"
//   4. Binary VLESS header + HTTP GET /generate_204, sent as a masked frame
//   5. Success only if the reply contains "HTTP/1.1 204" or "204 No Content"
// A candidate is confirmed with 3 probes (60 ms apart) and the average delay.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'py_compat.dart';

const int defaultTimeoutMs = 2400;
const List<int> wsMask = <int>[0x12, 0x34, 0x56, 0x78];
const int targetPort = 80;
const int maxHeaderBytes = 4096;
const int maxResponseBytes = 8192;
const int recvChunkBytes = 1024;
const int subnetHostCount = 254;
const int scanWorkers = 12;

final List<int> targetHost = utf8.encode('www.google.com');

class ScanResult {
  const ScanResult(this.ip, this.isSuccess, {this.delayMs = 0, this.error});

  final String ip;
  final bool isSuccess;
  final int delayMs;
  final String? error;
}

final RegExp _uuidHex = RegExp(r'^[0-9a-fA-F]{32}$');

/// 16 bytes of a UUID, like Python's uuid.UUID(s).bytes. Accepts the same
/// shapes: optional "urn:" / "uuid:" prefix, optional braces, hyphens.
List<int> uuidBytes(String uuidString) {
  var hex = uuidString.replaceAll('urn:', '').replaceAll('uuid:', '');
  hex = hex.replaceAll(RegExp(r'^[{}]+|[{}]+$'), '').replaceAll('-', '');
  if (!_uuidHex.hasMatch(hex)) {
    throw const FormatException('badly formed hexadecimal UUID string');
  }
  return <int>[
    for (var i = 0; i < 32; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
  ];
}

Uint8List buildVlessHeader(String uuid, {List<int>? target, int port = targetPort}) {
  final host = target ?? targetHost;
  final b = BytesBuilder();
  b.addByte(0); // version
  b.add(uuidBytes(uuid));
  b.addByte(0); // addon length
  b.addByte(1); // command: TCP
  b.addByte((port >> 8) & 0xFF);
  b.addByte(port & 0xFF);
  b.addByte(2); // address type: domain
  b.addByte(host.length & 0xFF);
  b.add(host);
  return b.toBytes();
}

Uint8List buildHttpPayload() => Uint8List.fromList(utf8.encode(
      'GET /generate_204 HTTP/1.1\r\n'
      'Host: www.google.com\r\n'
      'User-Agent: v2rayN\r\n'
      'Connection: close\r\n'
      '\r\n',
    ));

Uint8List buildFullVlessData(String uuid) {
  final b = BytesBuilder();
  b.add(buildVlessHeader(uuid));
  b.add(buildHttpPayload());
  return b.toBytes();
}

/// Masked WebSocket client binary frame, as in scanner.build_ws_frame.
Uint8List buildWsFrame(List<int> data, {List<int> mask = wsMask}) {
  final n = data.length;
  final b = BytesBuilder();
  if (n < 126) {
    b.add(<int>[0x82, 0x80 | n]);
  } else {
    b.add(<int>[0x82, 0x80 | 126, (n >> 8) & 0xFF, n & 0xFF]);
  }
  b.add(mask);
  for (var i = 0; i < n; i++) {
    b.addByte(data[i] ^ mask[i % 4]);
  }
  return b.toBytes();
}

Uint8List buildWsUpgradeRequest(String domain, String path) {
  final cleanPath = path.startsWith('/') ? path : '/$path';
  return Uint8List.fromList(utf8.encode(
    'GET $cleanPath HTTP/1.1\r\n'
    'Host: $domain\r\n'
    'Upgrade: websocket\r\n'
    'Connection: Upgrade\r\n'
    'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n'
    'Sec-WebSocket-Version: 13\r\n'
    'User-Agent: Mozilla/5.0 (Android; SpiderPanel)\r\n'
    '\r\n',
  ));
}

bool has204(List<int> buf) {
  if (buf.isEmpty) {
    return false;
  }
  final text = latin1.decode(buf);
  return text.contains('HTTP/1.1 204') || text.contains('204 No Content');
}

/// Reads a socket stream byte by byte or in chunks, with per-read timeouts
/// like Python's socket.settimeout(). Timeouts and socket errors are thrown;
/// a closed stream yields null.
class _ByteReader {
  _ByteReader(Stream<List<int>> stream) : _iterator = StreamIterator<List<int>>(stream);

  final StreamIterator<List<int>> _iterator;
  Uint8List _pending = Uint8List(0);
  int _pos = 0;
  bool _done = false;

  Future<bool> _ensure(Duration timeout) async {
    while (_pos >= _pending.length) {
      if (_done) {
        return false;
      }
      final hasNext = await _iterator.moveNext().timeout(timeout);
      if (!hasNext) {
        _done = true;
        return false;
      }
      _pending = Uint8List.fromList(_iterator.current);
      _pos = 0;
    }
    return true;
  }

  Future<int?> nextByte(Duration timeout) async {
    if (!await _ensure(timeout)) {
      return null;
    }
    return _pending[_pos++];
  }

  /// Up to [maxBytes] bytes; the rest of a longer block stays pending, the
  /// same way a recv(1024) leaves the rest in the kernel buffer.
  Future<Uint8List?> nextChunk(int maxBytes, Duration timeout) async {
    if (!await _ensure(timeout)) {
      return null;
    }
    final end = (_pos + maxBytes < _pending.length) ? _pos + maxBytes : _pending.length;
    final chunk = _pending.sublist(_pos, end);
    _pos = end;
    return chunk;
  }

  Future<void> cancel() async {
    _done = true;
    try {
      await _iterator.cancel();
    } catch (_) {}
  }
}

Future<Uint8List?> _readUntilDoubleCrlf(_ByteReader reader, Duration timeout) async {
  final buf = <int>[];
  const pattern = <int>[13, 10, 13, 10];
  var matched = 0;
  var totalRead = 0;
  while (totalRead < maxHeaderBytes) {
    final b = await reader.nextByte(timeout);
    if (b == null) {
      break;
    }
    totalRead++;
    buf.add(b);
    if (b == pattern[matched]) {
      matched++;
      if (matched == pattern.length) {
        return Uint8List.fromList(buf);
      }
    } else {
      matched = b == pattern[0] ? 1 : 0;
    }
  }
  return buf.isNotEmpty ? Uint8List.fromList(buf) : null;
}

Future<List<int>> _readUntil204(_ByteReader reader, Duration timeout) async {
  final buf = <int>[];
  final deadline = DateTime.now().add(timeout);
  while (buf.length < maxResponseBytes) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      break;
    }
    Uint8List? chunk;
    try {
      chunk = await reader.nextChunk(recvChunkBytes, remaining);
    } catch (_) {
      break; // timeout or socket error: stop collecting, as the Python does
    }
    if (chunk == null || chunk.isEmpty) {
      break;
    }
    buf.addAll(chunk);
    if (has204(buf)) {
      break;
    }
  }
  return buf;
}

SecurityContext _makeContext() {
  // Trust-all: onBadCertificate returns true. ALPN http/1.1 as in the original.
  final ctx = SecurityContext(withTrustedRoots: false);
  ctx.setAlpnProtocols(<String>['http/1.1'], false);
  return ctx;
}

SecurityContext? _sharedContext;

SecurityContext _context() {
  return _sharedContext ??= _makeContext();
}

/// Cooperative hard-stop for a scan. Probes register every socket they
/// open here; [abort] destroys them all at once, so in-flight connects
/// and handshakes fail immediately instead of running into their 2.4 s
/// timeouts. (Stop used to take ~5 s to land because the scan only
/// noticed the request between whole IPs, and one IP can mean three
/// sequential probes.) Probe RESULTS are unaffected — an aborted probe
/// simply returns as a failure, like a timeout would.
class ScanAbort {
  bool _aborted = false;
  final Set<Socket> _sockets = <Socket>{};

  bool get aborted => _aborted;

  void register(Socket socket) {
    if (_aborted) {
      socket.destroy();
    } else {
      _sockets.add(socket);
    }
  }

  void unregister(Socket socket) => _sockets.remove(socket);

  void abort() {
    _aborted = true;
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
    _sockets.clear();
  }
}

/// One probe. Never throws: failures are returned as ScanResult.
Future<ScanResult> runSingleProbe(
  String ip,
  String domain,
  String uuid, {
  String path = '/',
  int port = 443,
  ScanAbort? abort,
}) async {
  final sw = Stopwatch()..start();
  final timeout = const Duration(milliseconds: defaultTimeoutMs);
  Socket? rawSocket;
  SecureSocket? sslSocket;
  _ByteReader? reader;
  try {
    // 1. TCP connect
    rawSocket = await Socket.connect(ip, port, timeout: timeout);
    abort?.register(rawSocket);

    // 2. TLS with SNI = domain and ALPN http/1.1
    sslSocket = await SecureSocket.secure(
      rawSocket,
      host: domain,
      context: _context(),
      onBadCertificate: (_) => true,
    ).timeout(timeout);
    abort?.unregister(rawSocket);
    rawSocket = null; // ownership moved to sslSocket
    abort?.register(sslSocket);

    reader = _ByteReader(sslSocket);

    // 3. WebSocket upgrade
    sslSocket.add(buildWsUpgradeRequest(domain, path));
    await sslSocket.flush();

    final headerBytes = await _readUntilDoubleCrlf(reader, timeout);
    if (headerBytes == null) {
      return ScanResult(ip, false, error: 'No WS upgrade response');
    }
    final headerStr = utf8.decode(headerBytes, allowMalformed: true);
    final lines = pySplitLines(headerStr);
    final firstLine = lines.isNotEmpty ? lines.first : '';
    if (!firstLine.contains('101')) {
      return ScanResult(ip, false, error: 'WS Upgrade failed: $firstLine');
    }

    // 4+5. Binary VLESS frame + HTTP 204 probe, then read the reply
    sslSocket.add(buildWsFrame(buildFullVlessData(uuid)));
    await sslSocket.flush();

    final respBuf = await _readUntil204(reader, timeout);
    final delayMs = (sw.elapsedMicroseconds / 1000).toInt();

    if (has204(respBuf)) {
      return ScanResult(ip, true, delayMs: delayMs);
    }
    return ScanResult(ip, false, delayMs: delayMs, error: 'No valid Google 204 response');
  } catch (e) {
    final message = e.toString();
    return ScanResult(ip, false, error: message.isEmpty ? 'Connection error' : message);
  } finally {
    if (reader != null) {
      await reader.cancel();
    }
    if (sslSocket != null) {
      abort?.unregister(sslSocket);
    }
    sslSocket?.destroy();
    rawSocket?.destroy();
  }
}

/// Three-probe confirmation, as in scanner.test_ip_real_delay.
Future<ScanResult> testIpRealDelay(
  String ip,
  String domain,
  String uuid, {
  String path = '/',
  int port = 443,
  bool doubleCheck = true,
  ScanAbort? abort,
}) async {
  final first = await runSingleProbe(ip, domain, uuid, path: path, port: port, abort: abort);
  if (!first.isSuccess) {
    return first;
  }
  if (doubleCheck) {
    if (abort != null && abort.aborted) {
      return ScanResult(ip, false, error: 'Aborted');
    }
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final second = await runSingleProbe(ip, domain, uuid, path: path, port: port, abort: abort);
    if (!second.isSuccess) {
      return ScanResult(ip, false, error: 'Unstable connection (packet drop on 2nd probe)');
    }
    if (abort != null && abort.aborted) {
      return ScanResult(ip, false, error: 'Aborted');
    }
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final third = await runSingleProbe(ip, domain, uuid, path: path, port: port, abort: abort);
    if (!third.isSuccess) {
      return ScanResult(ip, false, error: 'Unstable connection (packet drop on 3rd probe)');
    }
    final avg = (first.delayMs + second.delayMs + third.delayMs) ~/ 3;
    return ScanResult(ip, true, delayMs: avg);
  }
  return first;
}

class _Ordered {
  _Ordered(this.result, this.seq);
  final ScanResult result;
  final int seq;
}

/// Scan .1 to .254 of a subnet prefix with 12 workers, results sorted by
/// delay. Equal delays keep arrival order (Python's sort is stable).
Future<List<ScanResult>> scanSubnet({
  required String subnetPrefix,
  required String domain,
  required String uuid,
  String path = '/',
  int port = 443,
  int maxWorkers = scanWorkers,
  void Function(int completed, int total, ScanResult result)? onProgress,
  bool Function()? shouldStop,
  ScanAbort? abort,
}) async {
  final prefix = subnetPrefix.endsWith('.') ? subnetPrefix : '$subnetPrefix.';
  final allIps = <String>[for (var i = 1; i <= subnetHostCount; i++) '$prefix$i'];

  final ordered = <_Ordered>[];
  var completed = 0;
  var nextIndex = 0;
  var seq = 0;
  var stopped = false;

  void sortResults() {
    ordered.sort((a, b) {
      final byDelay = a.result.delayMs.compareTo(b.result.delayMs);
      return byDelay != 0 ? byDelay : a.seq.compareTo(b.seq);
    });
  }

  Future<void> worker() async {
    while (!stopped && nextIndex < allIps.length) {
      if (shouldStop != null && shouldStop()) {
        stopped = true;
        return;
      }
      final ip = allIps[nextIndex++];
      final result = await testIpRealDelay(ip, domain, uuid, path: path, port: port, abort: abort);
      if (shouldStop != null && shouldStop()) {
        stopped = true;
        return;
      }
      completed++;
      if (result.isSuccess) {
        ordered.add(_Ordered(result, seq++));
        sortResults();
      }
      onProgress?.call(completed, subnetHostCount, result);
    }
  }

  await Future.wait(<Future<void>>[for (var i = 0; i < maxWorkers; i++) worker()]);
  sortResults();
  return <ScanResult>[for (final o in ordered) o.result];
}
