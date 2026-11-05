import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the release manifest's INTERNET permission.
///
/// The flutter create template only adds INTERNET to the debug/profile
/// manifests. A release build without it cannot open a single socket:
/// every probe fails instantly, the scan "completes" 254/254 with zero
/// results, and the app looks dead (this shipped in 2.0.0+3/+4 and was
/// caught by the user on a real phone, 2026-10-28).
void main() {
  test('the main AndroidManifest grants INTERNET', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      manifest,
      contains('android.permission.INTERNET'),
      reason: 'Release builds need INTERNET or no scan can ever succeed.',
    );
  });
}
