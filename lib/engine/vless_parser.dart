// VLESS config parser — pure Dart, behaviour-identical to the reference
// implementation covered by the golden tests.

import 'dart:convert';

import 'py_compat.dart';

class VlessConfig {
  const VlessConfig({
    required this.uuid,
    required this.address,
    this.port = 443,
    this.domain = '',
    this.path = '/',
    this.security = 'tls',
    this.type = 'ws',
    this.name = 'Clean Railway',
  });

  final String uuid;
  final String address;
  final int port;
  final String domain;
  final String path;
  final String security;
  final String type;
  final String name;
}

final RegExp _unicodeDecimal = RegExp(r'\p{Nd}', unicode: true);

bool _isAsciiHex(int c) =>
    (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x46) || (c >= 0x61 && c <= 0x66);

/// Port of Python's `_url_decode` (Java URLDecoder rules). Throws
/// FormatException where Python raises ValueError.
String urlDecode(String value) {
  final out = StringBuffer();
  final buf = <int>[];

  void flush() {
    if (buf.isNotEmpty) {
      out.write(utf8.decode(buf, allowMalformed: true));
      buf.clear();
    }
  }

  var i = 0;
  final n = value.length;
  while (i < n) {
    final c = value[i];
    if (c == '%') {
      if (i + 2 >= n) {
        throw const FormatException('URLDecoder: incomplete trailing escape (%) pattern');
      }
      final h0 = value.codeUnitAt(i + 1);
      final h1 = value.codeUnitAt(i + 2);
      if (!_isAsciiHex(h0) || !_isAsciiHex(h1)) {
        throw const FormatException('URLDecoder: illegal hex characters in escape (%) pattern');
      }
      buf.add(int.parse(value.substring(i + 1, i + 3), radix: 16));
      i += 3;
      continue;
    }
    flush();
    out.write(c == '+' ? ' ' : c);
    i++;
  }
  flush();
  return out.toString();
}

/// Decimal value of one code point, or null if it is not a Unicode decimal
/// digit (Python str.isdecimal()). Unicode decimal digits come in runs whose
/// zero is at a run start, so the value is the offset from that start mod 10.
int? _decimalValue(int cp) {
  if (cp >= 0x30 && cp <= 0x39) {
    return cp - 0x30;
  }
  if (!_unicodeDecimal.hasMatch(String.fromCharCode(cp))) {
    return null;
  }
  var start = cp;
  while (start > 0 && _unicodeDecimal.hasMatch(String.fromCharCode(start - 1))) {
    start--;
  }
  return (cp - start) % 10;
}

/// Port of Kotlin String.toIntOrNull() (32-bit signed). Returns null for
/// anything Kotlin would reject, including values outside the Int range.
int? kotlinToIntOrNull(String s) {
  if (s.isEmpty) {
    return null;
  }
  var start = 0;
  var negative = false;
  final first = s.codeUnitAt(0);
  if (first == 0x2B || first == 0x2D) {
    negative = first == 0x2D;
    start = 1;
    if (s.length == 1) {
      return null;
    }
  }
  var result = 0;
  for (final cp in s.substring(start).runes) {
    final digit = _decimalValue(cp);
    if (digit == null) {
      return null;
    }
    result = result * 10 + digit;
    if (result > 2147483648) {
      return null;
    }
  }
  if (negative) {
    result = -result;
  }
  if (result < -2147483648 || result > 2147483647) {
    return null;
  }
  return result;
}

bool _isUriUnreserved(int b) {
  return (b >= 0x41 && b <= 0x5A) || // A-Z
      (b >= 0x61 && b <= 0x7A) || // a-z
      (b >= 0x30 && b <= 0x39) || // 0-9
      b == 0x5F || // _
      b == 0x2E || // .
      b == 0x2D || // -
      b == 0x7E || // ~
      b == 0x21 || // !
      b == 0x27 || // '
      b == 0x28 || // (
      b == 0x29 || // )
      b == 0x2A; // *
}

/// Port of Python's `_uri_encode` (quote with safe="!~'()*"): UTF-8 bytes,
/// unreserved characters left as-is, everything else %XX (uppercase).
String uriEncode(String value) {
  final out = StringBuffer();
  for (final b in utf8.encode(value)) {
    if (_isUriUnreserved(b)) {
      out.writeCharCode(b);
    } else {
      out.write('%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return out.toString();
}

/// Parse a vless:// URI. Returns null on failure, like parser.py.
VlessConfig? parse(String vlessUri) {
  try {
    final trimmed = pyStrip(vlessUri);
    const scheme = 'vless://';
    if (!trimmed.startsWith(scheme)) {
      return null;
    }
    final withoutScheme = trimmed.substring(scheme.length);
    final atIndex = withoutScheme.indexOf('@');
    if (atIndex == -1) {
      return null;
    }
    final uuid = withoutScheme.substring(0, atIndex);
    final rest = withoutScheme.substring(atIndex + 1);

    final questionIndex = rest.indexOf('?');
    final hashIndex = rest.indexOf('#');

    final String hostPort;
    if (questionIndex != -1) {
      hostPort = rest.substring(0, questionIndex);
    } else if (hashIndex != -1) {
      hostPort = rest.substring(0, hashIndex);
    } else {
      hostPort = rest;
    }

    final hostParts = hostPort.split(':');
    final address = hostParts[0];
    var port = 443;
    if (hostParts.length > 1) {
      port = kotlinToIntOrNull(hostParts[1]) ?? 443;
    }

    var path = '/';
    var sni = address;
    var security = 'tls';
    var type = 'ws';
    var name = 'Clean Railway';

    if (hashIndex != -1) {
      name = urlDecode(rest.substring(hashIndex + 1));
    }

    if (questionIndex != -1) {
      final queryEnd = hashIndex != -1 ? hashIndex : rest.length;
      if (questionIndex + 1 > queryEnd) {
        // The first '?' sits inside the fragment: Kotlin substring throws.
        return null;
      }
      final queryStr = rest.substring(questionIndex + 1, queryEnd);
      for (final param in queryStr.split('&')) {
        final kv = param.split('=');
        if (kv.length == 2) {
          final k = kv[0].toLowerCase();
          final v = urlDecode(kv[1]);
          if (k == 'path') {
            path = v;
          } else if (k == 'sni') {
            sni = v;
          } else if (k == 'host') {
            if (sni.isEmpty || sni == address) {
              sni = v;
            }
          } else if (k == 'security') {
            security = v;
          } else if (k == 'type') {
            type = v;
          }
        }
      }
    }

    if (sni.isEmpty) {
      sni = address;
    }

    return VlessConfig(
      uuid: uuid,
      address: address,
      port: port,
      domain: sni,
      path: path,
      security: security,
      type: type,
      name: name,
    );
  } catch (_) {
    return null;
  }
}

/// Split pasted text into vless:// candidates (split on the scheme, first
/// line of each chunk). Same as parser.split_candidates().
List<String> splitCandidates(String text) {
  if (text.isEmpty) {
    return <String>[];
  }
  final out = <String>[];
  for (final chunk in text.split('vless://').skip(1)) {
    final stripped = pyStrip(chunk);
    final firstLine = stripped.isEmpty ? '' : pyStrip(pySplitLines(stripped).first);
    if (firstLine.isNotEmpty) {
      out.add('vless://$firstLine');
    }
  }
  return out;
}

/// First valid link in pasted text, and how many candidates were found.
(VlessConfig?, int) parseFirst(String text) {
  final candidates = splitCandidates(text);
  for (final candidate in candidates) {
    final cfg = parse(candidate);
    if (cfg != null) {
      return (cfg, candidates.length);
    }
  }
  return (null, candidates.length);
}

/// Every valid link in pasted text, in paste order. Built from the same
/// [splitCandidates] + [parse] pair as [parseFirst], so per-link results
/// are identical by construction.
List<VlessConfig> parseAll(String text) {
  final out = <VlessConfig>[];
  for (final candidate in splitCandidates(text)) {
    final cfg = parse(candidate);
    if (cfg != null) {
      out.add(cfg);
    }
  }
  return out;
}

/// buildConfigLink from parser.py: replaces the IP and keeps the original
/// config name verbatim (no ping or rank suffix).
String buildConfigLink(VlessConfig base, String newIp) {
  final rawPath = base.path.startsWith('/') ? base.path : '/${base.path}';
  final encodedPath = uriEncode(rawPath);
  final serverName = uriEncode(base.name);
  return 'vless://${base.uuid}@$newIp:${base.port}'
      '?encryption=none&security=${base.security}&sni=${base.domain}'
      '&fp=chrome&alpn=http%2F1.1&type=${base.type}&host=${base.domain}'
      '&path=$encodedPath#$serverName';
}
