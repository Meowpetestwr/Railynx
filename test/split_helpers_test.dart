// Direct checks of the Python-compatibility helpers.

import 'package:railway_clean_ip_scanner/engine/py_compat.dart';
import 'package:test/test.dart';

void main() {
  test('pyStrip strips Python whitespace, including \\x1c-\\x1f', () {
    expect(pyStrip('\x1cabc\x1f'), 'abc');
    expect(pyStrip('  \t\n x \u3000'), 'x');
    expect(pyStrip('\uFEFFabc'), '\uFEFFabc'); // BOM is not whitespace in Python
  });

  test('pySplitLines splits on Python line separators', () {
    expect(pySplitLines('a\r\nb'), ['a', 'b']);
    expect(pySplitLines('a\u2028b'), ['a', 'b']);
    expect(pySplitLines('a\x0bb'), ['a', 'b']);
    expect(pySplitLines('a\n'), ['a']);
    expect(pySplitLines(''), <String>[]);
  });
}
