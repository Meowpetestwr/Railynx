import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app/controller.dart';
import 'app/fps.dart';
import 'app/prefs_store.dart';
import 'app/probe_engine.dart';
import 'app/tokens.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On Android the executable directory is read-only, so settings live in
  // the app documents folder instead; on desktop they stay beside the
  // executable, as the Python app kept them.
  final PrefsStore prefs;
  if (Platform.isAndroid) {
    final dir = await getApplicationDocumentsDirectory();
    prefs = PrefsStore(File('${dir.path}/railway_scanner_prefs.json'));
  } else {
    prefs = PrefsStore.beside(Platform.resolvedExecutable);
  }
  final controller = AppController(engine: RealProbeEngine(), prefs: prefs);
  await applyFpsLimit(controller.fpsLimit);
  runApp(ScannerApp(controller: controller));
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Tokens.teal,
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Railynx',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: Tokens.bg,
        fontFamily: Tokens.uiFont,
        textSelectionTheme: const TextSelectionThemeData(cursorColor: Tokens.teal),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Tokens.surface,
          isDense: true,
          hintStyle: const TextStyle(color: Tokens.ink3, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Tokens.edge.withValues(alpha: 0.16)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Tokens.edge.withValues(alpha: 0.16)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Tokens.teal),
          ),
        ),
      ),
      home: _Shell(controller: controller),
    );
  }
}

/// Wraps the page so SnackBars have a ScaffoldMessenger above HomePage.
class _Shell extends StatelessWidget {
  const _Shell({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(child: HomePage(controller: controller));
  }
}
