import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('railynx/fps');

/// Ask Android to cap this window's refresh rate (0 = no preference,
/// the panel runs at its maximum). A no-op wherever the platform side
/// doesn't exist (desktop builds ignore the setting).
Future<void> applyFpsLimit(int fps) async {
  try {
    await _channel.invokeMethod<void>('set', <String, Object?>{'fps': fps});
  } on MissingPluginException {
    // Not Android — nothing to cap.
  } on PlatformException {
    // The platform refused; the app simply runs uncapped.
  }
}
