import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railway_clean_ip_scanner/app/controller.dart';
import 'package:railway_clean_ip_scanner/main.dart';
import 'package:railway_clean_ip_scanner/ui/widgets.dart';

import '../fakes.dart';

void _useDesktopSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

AppController _controller(FakeEngine engine) {
  final c = AppController(engine: engine);
  c.animatedAurora = false;
  return c;
}

void main() {
  testWidgets('empty state renders the title, status and empty results text', (tester) async {
    _useDesktopSize(tester);
    final c = _controller(FakeEngine());
    addTearDown(c.dispose);
    await tester.pumpWidget(ScannerApp(controller: c));
    await tester.pump();

    expect(find.text('Twilight edition'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Start scan'), findsOneWidget);
    expect(find.text('Railynx'), findsWidgets);
    expect(
      find.text('Real checks, ranked results, ready-to-paste configs.'),
      findsOneWidget,
    );
    expect(find.text('No clean IPs yet'), findsOneWidget);
    expect(
      find.text('Start a scan. Every IP is verified through a real tunnel, and the fastest ones appear here, ranked.'),
      findsOneWidget,
    );
    expect(find.text('Copy top 5'), findsOneWidget);
    expect(find.text('Build configs'), findsOneWidget);
  });

  testWidgets('starting a scan without a config shows the paste-first toast', (tester) async {
    _useDesktopSize(tester);
    final c = _controller(FakeEngine());
    addTearDown(c.dispose);
    await tester.pumpWidget(ScannerApp(controller: c));
    await tester.pump();

    await tester.tap(find.text('Start scan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Paste a VLESS config first to load your server'), findsOneWidget);
    expect(
      find.text('Please paste a VLESS config above to load your server.'),
      findsOneWidget,
    );
  });

  testWidgets('results show the fastest card and the ranked list', (tester) async {
    _useDesktopSize(tester);
    final engine = FakeEngine(scanResults: [ok('10.0.0.1', 90), ok('10.0.0.2', 240)]);
    final c = _controller(engine);
    addTearDown(c.dispose);
    await c.parseLink(sampleLink);
    await tester.pumpWidget(ScannerApp(controller: c));
    await tester.runAsync(() => c.toggleScan());
    await tester.pump();

    expect(find.text('FASTEST'), findsOneWidget);
    expect(find.text('TOP PICK'), findsOneWidget);
    expect(find.text('STABLE'), findsOneWidget);
    expect(find.text('Clean IPs'), findsOneWidget);
    expect(find.text('by delay'), findsOneWidget);
    expect(find.text('01'), findsNothing);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('90 ms'), findsWidgets);
    expect(find.text('240 ms'), findsOneWidget);
  });

  testWidgets('Build configs opens the workbench with the rows and actions', (tester) async {
    _useDesktopSize(tester);
    final engine = FakeEngine(scanResults: [ok('10.0.0.1', 90)]);
    final c = _controller(engine);
    addTearDown(c.dispose);
    await c.parseLink(sampleLink);
    await tester.pumpWidget(ScannerApp(controller: c));
    await tester.runAsync(() => c.toggleScan());
    await tester.pump();

    await tester.tap(find.text('Build configs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('CONFIGS'), findsOneWidget);
    expect(find.text('Top N'), findsOneWidget);
    expect(find.text('Best for all'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Test these'), findsOneWidget);
    expect(find.text('Generate & copy'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('05'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('05'), findsOneWidget);
    expect(find.text('Only 1 clean IP found, so some configs will share one.'), findsOneWidget);
  });

  testWidgets('the workbench says to scan first when there are no results', (tester) async {
    _useDesktopSize(tester);
    final c = _controller(FakeEngine());
    addTearDown(c.dispose);
    await tester.pumpWidget(ScannerApp(controller: c));
    await tester.pump();

    await tester.tap(find.text('Build configs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Scan first to build configs'), findsOneWidget);
  });

  testWidgets('there is no Parse button, and Paste parses the link at once', (tester) async {
    _useDesktopSize(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': sampleLink};
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final c = _controller(FakeEngine());
    addTearDown(c.dispose);
    await tester.pumpWidget(ScannerApp(controller: c));
    await tester.pump();

    expect(find.text('Parse'), findsNothing);
    expect(find.text('Paste'), findsOneWidget);

    await tester.tap(find.text('Paste'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(c.uuid.text, isNotEmpty);
    expect(c.parseHint, startsWith('Parsed VLESS'));
  });

  testWidgets('the idle ring shows 0 of 254 and the Ready status', (tester) async {
    _useDesktopSize(tester);
    final c = _controller(FakeEngine());
    addTearDown(c.dispose);
    await tester.pumpWidget(ScannerApp(controller: c));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(ScanRing), findsOneWidget);
    expect(find.text('of 254'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('the layout fits a phone-sized window', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = _controller(FakeEngine());
    addTearDown(c.dispose);
    await tester.pumpWidget(ScannerApp(controller: c));
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
    expect(find.text('Start scan'), findsOneWidget);
    expect(find.text('Copy top 5'), findsOneWidget);
  });
}
