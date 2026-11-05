import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railway_clean_ip_scanner/app/controller.dart';
import 'package:railway_clean_ip_scanner/app/prefs_store.dart';
import 'package:railway_clean_ip_scanner/main.dart';
import 'package:railway_clean_ip_scanner/ui/settings_page.dart';
import 'package:railway_clean_ip_scanner/ui/widgets.dart';

import '../fakes.dart';

void main() {
  group('appearance presets', () {
    test('defaults are the full shipped look', () {
      final c = AppController(engine: FakeEngine());
      addTearDown(c.dispose);
      expect(c.uiPreset, 'original');
      expect(c.animatedAurora, isTrue);
      expect(c.fxBlobs, isTrue);
      expect(c.fxWashes, isTrue);
      expect(c.fxDockBlur, isTrue);
      expect(c.fxRichShadows, isTrue);
      expect(c.fxGlowBlur, isTrue);
      expect(c.fxHalfRes, isFalse);
      expect(c.fxLiteRows, isTrue);
      expect(c.fpsLimit, 0);
      expect(c.fxButtonFlow, isTrue);
      expect(c.fxRingGlow, isTrue);
      expect(c.fxRowAnimations, isTrue);
    });

    test('performance preset turns every effect off', () {
      final c = AppController(engine: FakeEngine());
      addTearDown(c.dispose);
      c.applyPreset('performance');
      expect(c.uiPreset, 'performance');
      expect(c.animatedAurora, isFalse);
      expect(c.fxBlobs, isFalse);
      expect(c.fxWashes, isFalse);
      expect(c.fxDockBlur, isFalse);
      expect(c.fxButtonFlow, isFalse);
      expect(c.fxRingGlow, isFalse);
      expect(c.fxRowAnimations, isFalse);
      expect(c.fxRichShadows, isFalse);
      expect(c.fxGlowBlur, isFalse);
      expect(c.fxHalfRes, isTrue);
    });

    test('balanced keeps the aurora but draws it the cheap way', () {
      final c = AppController(engine: FakeEngine());
      addTearDown(c.dispose);
      c.applyPreset('balanced');
      expect(c.uiPreset, 'balanced');
      expect(c.fxBlobs, isTrue);
      expect(c.fxWashes, isTrue);
      expect(c.fxRingGlow, isTrue);
      expect(c.animatedAurora, isFalse);
      expect(c.fxDockBlur, isTrue);
      expect(c.fxButtonFlow, isFalse);
      expect(c.fxRichShadows, isFalse);
      expect(c.fxGlowBlur, isFalse);
      expect(c.fxHalfRes, isTrue);
    });

    test('touching one switch makes the preset custom, restoring it re-derives', () {
      final c = AppController(engine: FakeEngine());
      addTearDown(c.dispose);
      c.setFx(blobs: false);
      expect(c.uiPreset, 'custom');
      c.setFx(blobs: true);
      expect(c.uiPreset, 'original');
    });

    test('settings survive a restart (prefs round-trip)', () async {
      final dir = await Directory.systemTemp.createTemp('railynx_prefs');
      addTearDown(() => dir.delete(recursive: true));
      final store = PrefsStore(File('${dir.path}/prefs.json'));

      final a = AppController(engine: FakeEngine(), prefs: store);
      a.applyPreset('balanced');
      a.setFx(ringGlow: false);
      a.dispose();

      final b = AppController(engine: FakeEngine(), prefs: store);
      addTearDown(b.dispose);
      expect(b.animatedAurora, isFalse);
      expect(b.fxDockBlur, isTrue);
      expect(b.fxBlobs, isTrue);
      expect(b.fxRingGlow, isFalse);
      expect(b.uiPreset, 'custom');
    });

    test('frame-rate cap and new look flags persist', () async {
      final dir = await Directory.systemTemp.createTemp('railynx_prefs');
      addTearDown(() => dir.delete(recursive: true));
      final store = PrefsStore(File('${dir.path}/prefs.json'));

      final a = AppController(engine: FakeEngine(), prefs: store);
      expect(a.fpsLimit, 0);
      a.setFpsLimit(60);
      a.setFx(richShadows: false, halfRes: true, liteRows: false);
      a.dispose();

      final b = AppController(engine: FakeEngine(), prefs: store);
      addTearDown(b.dispose);
      expect(b.fpsLimit, 60);
      expect(b.fxRichShadows, isFalse);
      expect(b.fxHalfRes, isTrue);
      expect(b.fxLiteRows, isFalse);
    });
  });

  group('settings page', () {
    testWidgets('gear opens it; preset card and switches drive the controller', (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final c = AppController(engine: FakeEngine());
      // The aurora clock repeats forever; freeze it so pumps can settle.
      c.animatedAurora = false;
      addTearDown(c.dispose);
      await tester.pumpWidget(ScannerApp(controller: c));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Performance'), findsOneWidget);

      await tester.tap(find.text('Performance'));
      await tester.pump();
      expect(c.uiPreset, 'performance');
      expect(c.fxBlobs, isFalse);

      // Flip "Aurora lights" (the second switch) back on: preset -> custom.
      // (Finders are scoped to the settings page — the home page's own
      // ListView is still in the tree underneath the pushed route.)
      final pageList = find.descendant(of: find.byType(SettingsPage), matching: find.byType(ListView));
      await tester.drag(pageList, const Offset(0, -320));
      await tester.pump(const Duration(milliseconds: 300));
      final pageSwitches = find.descendant(of: find.byType(SettingsPage), matching: find.byType(AppSwitch));
      await tester.tap(pageSwitches.at(1));
      await tester.pump();
      expect(c.fxBlobs, isTrue);
      expect(c.uiPreset, 'custom');
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('frame-rate segmented control drives the fps limit', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = AppController(engine: FakeEngine());
      addTearDown(c.dispose);
      await tester.pumpWidget(ScannerApp(controller: c));
      await tester.pump();
      expect(c.fpsLimit, 0);

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsPage), findsOneWidget);

      final pageScrollable = find.descendant(of: find.byType(SettingsPage), matching: find.byType(Scrollable));
      await tester.scrollUntilVisible(
        find.text('Refresh-rate cap'),
        300,
        scrollable: pageScrollable,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Refresh-rate cap'), findsOneWidget);
      await tester.tap(find.text('60'));
      await tester.pump();
      expect(c.fpsLimit, 60);
      await tester.tap(find.text('30'));
      await tester.pump();
      expect(c.fpsLimit, 30);
    });
  });
}
