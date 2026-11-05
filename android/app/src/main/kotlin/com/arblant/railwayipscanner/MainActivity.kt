package com.arblant.railwayipscanner

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Settings -> Frame rate: cap this window's refresh rate
        // (0 = no preference, the panel's maximum). The Dart side
        // treats every failure as "run uncapped".
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "railynx/fps")
            .setMethodCallHandler { call, result ->
                if (call.method == "set") {
                    val fps = call.argument<Number>("fps")?.toFloat() ?: 0f
                    val attrs = window.attributes
                    attrs.preferredRefreshRate = fps
                    window.attributes = attrs
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
