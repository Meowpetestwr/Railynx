import 'dart:convert';
import 'dart:io';

/// Settings in railway_scanner_prefs.json, the same file name and keys as the
/// Python app. It lives next to the executable, as the frozen Python app does.
class PrefsStore {
  PrefsStore(this.file);

  factory PrefsStore.beside(String executablePath) {
    final dir = File(executablePath).parent.path;
    return PrefsStore(File('$dir${Platform.pathSeparator}railway_scanner_prefs.json'));
  }

  final File file;

  Map<String, dynamic> read() {
    try {
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is Map<String, dynamic>) {
        return raw;
      }
    } catch (_) {
      // missing or unreadable: defaults apply
    }
    return <String, dynamic>{};
  }

  /// Merges [updates] into the stored object, keeping the other keys.
  void merge(Map<String, Object?> updates) {
    final current = read();
    current.addAll(updates);
    try {
      file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(current));
    } catch (_) {
      // a read-only install folder must not break the app
    }
  }
}
