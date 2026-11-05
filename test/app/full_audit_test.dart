import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railway_clean_ip_scanner/app/controller.dart';
import 'package:railway_clean_ip_scanner/app/prefs_store.dart';
import 'package:railway_clean_ip_scanner/main.dart';
import 'package:railway_clean_ip_scanner/ui/settings_page.dart';
import 'package:railway_clean_ip_scanner/ui/widgets.dart';

import '../fakes.dart';
import 'package:railway_clean_ip_scanner/ui/home_page.dart';

/// Full-audit tests added for the 2.0.0+10 verification pass: every
/// Settings switch must drive the flag it claims to, a prefs file from
/// the previous release must upgrade cleanly, and every preset /
/// glow / row variant must paint without exceptions.
void main() {
  group('settings wiring sweep', () {
    testWidgets('every switch flips exactly its own controller flag', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = AppController(engine: FakeEngine());
      addTearDown(c.dispose);
      await tester.pumpWidget(ScannerApp(controller: c));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsPage), findsOneWidget);

      final cases = <String, bool Function(AppController)>{
        'Animated aurora': (c) => c.animatedAurora,
        'Aurora lights': (c) => c.fxBlobs,
        'Half-resolution aurora': (c) => c.fxHalfRes,
        'Light washes': (c) => c.fxWashes,
        'Rich shadows': (c) => c.fxRichShadows,
        'Blurred glow': (c) => c.fxGlowBlur,
        'Dock blur': (c) => c.fxDockBlur,
        'Button flow': (c) => c.fxButtonFlow,
        'Ring glow': (c) => c.fxRingGlow,
        'Row animations': (c) => c.fxRowAnimations,
        'Lightweight rows': (c) => c.fxLiteRows,
      };
      final scrollable = find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      );
      for (final entry in cases.entries) {
        await tester.scrollUntilVisible(find.text(entry.key), 250, scrollable: scrollable);
        await tester.pump(const Duration(milliseconds: 250));
        final sw = find.descendant(
          of: find.ancestor(of: find.text(entry.key), matching: find.byType(Row)),
          matching: find.byType(AppSwitch),
        );
        expect(sw, findsOneWidget, reason: 'switch for ${entry.key}');
        final before = entry.value(c);
        await tester.tap(sw);
        await tester.pump();
        expect(entry.value(c), !before, reason: '${entry.key} must flip its flag');
        expect(tester.takeException(), isNull, reason: '${entry.key} tap');
      }
    });
  });

  group('settings reach the home page', () {
    testWidgets('a switch flipped in Settings restyles the home backdrop after popping back', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = AppController(engine: FakeEngine());
      addTearDown(c.dispose);
      await tester.pumpWidget(ScannerApp(controller: c));
      await tester.pump();

      AuroraBackdrop homeBackdrop() => tester.widget<AuroraBackdrop>(
            find.descendant(of: find.byType(HomePage), matching: find.byType(AuroraBackdrop)),
          );
      expect(homeBackdrop().showBlobs, isTrue);
      expect(homeBackdrop().animated, isTrue);

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsPage), findsOneWidget);

      final scrollable = find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      );
      for (final title in <String>['Aurora lights', 'Animated aurora']) {
        await tester.scrollUntilVisible(find.text(title), 250, scrollable: scrollable);
        await tester.pump(const Duration(milliseconds: 250));
        final sw = find.descendant(
          of: find.ancestor(of: find.text(title), matching: find.byType(Row)),
          matching: find.byType(AppSwitch),
        );
        await tester.tap(sw);
        await tester.pump();
      }
      expect(c.fxBlobs, isFalse);
      expect(c.animatedAurora, isFalse);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The home backdrop must have received the new values even though
      // the change happened while Settings covered it.
      expect(homeBackdrop().showBlobs, isFalse, reason: 'home backdrop ignored the blobs switch');
      expect(homeBackdrop().animated, isFalse, reason: 'home backdrop ignored the animation switch');
      expect(tester.takeException(), isNull);
    });
  });

  group('empty state layout', () {
    testWidgets('the empty card content is centered in the card', (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = AppController(engine: FakeEngine());
      c.animatedAurora = false;
      addTearDown(c.dispose);
      await tester.pumpWidget(ScannerApp(controller: c));
      await tester.pump();
      final cardFinder = find.ancestor(of: find.text('No clean IPs yet'), matching: find.byType(GlassCard));
      final card = tester.getRect(cardFinder);
      final title = tester.getRect(find.text('No clean IPs yet'));
      final orbit = tester.getRect(
        find.descendant(of: cardFinder, matching: find.byType(OrbitArt)),
      );
      expect((title.center.dx - card.center.dx).abs(), lessThan(2),
          reason: 'title must sit at the card’s horizontal center');
      expect((orbit.center.dx - card.center.dx).abs(), lessThan(2),
          reason: 'orbit art must sit at the card’s horizontal center');
    });
  });

  group('prefs upgrade from the previous release', () {
    test('a +7-era prefs file loads with the new defaults', () async {
      final dir = await Directory.systemTemp.createTemp('railynx_upgrade');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/prefs.json');
      // Exactly the keys 2.0.0+7 could write — no fx_rich_shadows,
      // no fx_glow_blur, no fx_half_res, no fx_lite_rows, no fps_limit.
      file.writeAsStringSync(jsonEncode(<String, Object?>{
        'aurora_anim': true,
        'fx_blobs': true,
        'fx_washes': true,
        'fx_dock_blur': true,
        'fx_button_flow': true,
        'fx_ring_glow': true,
        'fx_row_anim': true,
      }));

      final c = AppController(engine: FakeEngine(), prefs: PrefsStore(file));
      addTearDown(c.dispose);
      expect(c.fxRichShadows, isTrue);
      expect(c.fxGlowBlur, isTrue);
      expect(c.fxHalfRes, isFalse);
      expect(c.fxLiteRows, isTrue);
      expect(c.fpsLimit, 0);
      expect(c.uiPreset, 'original');
    });
  });

  group('paint smoke across look variants', () {
    testWidgets('every preset and glow/row variant paints clean with results', (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = FakeEngine(
        scanResults: [ok('10.0.0.1', 90), ok('10.0.0.2', 240), ok('10.0.0.3', 700)],
      );
      final c = AppController(engine: engine);
      addTearDown(c.dispose);
      await c.parseLink(sampleLink);
      await tester.pumpWidget(ScannerApp(controller: c));
      await tester.runAsync(() => c.toggleScan());
      await tester.pump();
      expect(find.text('FASTEST'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final preset in <String>['original', 'balanced', 'performance']) {
        c.applyPreset(preset);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull, reason: 'preset $preset');
      }
      // The mixed custom state: stepped glow + wrapped rows + half-res.
      c.setFx(glowBlur: false, liteRows: false, halfRes: true, richShadows: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull, reason: 'custom mix');
      // And back to the blurred glow with lite rows.
      c.setFx(glowBlur: true, liteRows: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull, reason: 'blurred + lite');
    });
  });
}
