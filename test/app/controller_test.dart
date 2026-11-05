import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railway_clean_ip_scanner/app/controller.dart';
import 'package:railway_clean_ip_scanner/app/workbench_model.dart';
import 'package:railway_clean_ip_scanner/engine/vless_parser.dart';

import '../fakes.dart';

String? clipboardText;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardText ?? ''};
      }
      return null;
    });
  });

  AppController make(FakeEngine engine) {
    final c = AppController(engine: engine);
    c.animatedAurora = false;
    return c;
  }

  test('parseLink fills the fields and reports the name', () async {
    final c = make(FakeEngine());
    addTearDown(c.dispose);
    await c.parseLink(sampleLink);
    expect(c.domain.text, 'fast-a.up.railway.app');
    expect(c.uuid.text, '11111111-2222-3333-4444-555555555555');
    expect(c.path.text, '/ws');
    expect(c.parseHint, 'Parsed VLESS: My Railway Config');
    expect(c.parseHintOk, isTrue);
    expect(c.parsed?.name, 'My Railway Config');
  });

  test('parseLink on text with two links keeps both (same server)', () async {
    final c = make(FakeEngine());
    addTearDown(c.dispose);
    await c.parseLink('$sampleLink\n$sampleLink');
    expect(c.parseHint, 'Parsed VLESS: My Railway Config  ·  2 configs · same server');
    expect(c.parsedAll.length, 2);
    expect(c.multiConfigs, isTrue);
    expect(c.multiGroups, isFalse);
  });

  test('parseLink with no valid link shows the error hint', () async {
    final c = make(FakeEngine());
    addTearDown(c.dispose);
    await c.parseLink('vless://not-valid');
    expect(c.parseHint, 'No valid vless:// link found.');
    expect(c.parseHintOk, isFalse);
  });

  test('paste reads the clipboard natively and parses a vless link', () async {
    final c = make(FakeEngine());
    addTearDown(c.dispose);
    clipboardText = sampleLink;
    await c.pasteFromClipboard();
    expect(c.link.text, sampleLink);
    expect(c.parseHintOk, isTrue);
  });

  test('paste of non-vless text says so', () async {
    final c = make(FakeEngine());
    addTearDown(c.dispose);
    clipboardText = 'hello';
    await c.pasteFromClipboard();
    expect(c.parseHint, 'Clipboard does not contain a vless:// link.');
  });

  test('scan with no config shows the paste-first message and does not scan', () async {
    final engine = FakeEngine(scanResults: [ok('10.0.0.1', 90)]);
    final c = make(engine);
    addTearDown(c.dispose);
    final toasts = <String>[];
    c.toast = toasts.add;
    await c.toggleScan();
    expect(c.status, ScanStatus.idle);
    expect(c.statusLine, 'Please paste a VLESS config above to load your server.');
    expect(toasts, ['Paste a VLESS config first to load your server']);
  });

  test('scan keeps successes sorted by delay and reports completion', () async {
    final engine = FakeEngine(scanResults: [
      ok('10.0.0.9', 300),
      dead('10.0.0.5'),
      ok('10.0.0.1', 90),
      ok('10.0.0.2', 90),
    ]);
    final c = make(engine);
    addTearDown(c.dispose);
    await c.parseLink(sampleLink);
    await c.toggleScan();
    expect(c.status, ScanStatus.done);
    expect(c.results.map((r) => r.ip).toList(), ['10.0.0.1', '10.0.0.2', '10.0.0.9']);
    expect(c.statusLine, 'Scan completed! Found 3 100% verified clean IPs.');
    expect(c.scanned, 4);
  });

  test('top mode with fewer IPs than configs wraps and shows the notice', () async {
    final engine = FakeEngine(scanResults: [ok('10.0.0.1', 90), ok('10.0.0.2', 120)]);
    final c = make(engine);
    addTearDown(c.dispose);
    await c.parseLink(sampleLink);
    await c.toggleScan();
    c.setCount(5);
    expect(c.rows.map((r) => r.ip).toList(),
        ['10.0.0.1', '10.0.0.2', '10.0.0.1', '10.0.0.2', '10.0.0.1']);
    expect(WorkbenchModel.shortage(mode: c.genMode, count: c.genCount, resultCount: c.results.length),
        isTrue);
  });

  test('count is clamped to 1..20', () {
    final c = make(FakeEngine());
    addTearDown(c.dispose);
    c.setCount(99);
    expect(c.genCount, genMax);
    c.setCount(0);
    expect(c.genCount, genMin);
  });

  test('custom picks survive a rescan but a vanished pick goes stale', () async {
    final engine = FakeEngine(scanResults: [ok('10.0.0.1', 90), ok('10.0.0.2', 120)]);
    final c = make(engine);
    addTearDown(c.dispose);
    await c.parseLink(sampleLink);
    await c.toggleScan();
    c.setMode('custom');
    c.pickIp(0, '10.0.0.2');
    expect(c.rows[0].changed, isTrue);

    final rescanned = make(FakeEngine(scanResults: [ok('10.0.0.1', 90)]));
    addTearDown(rescanned.dispose);
    rescanned.custom.addAll(c.custom);
    rescanned.setMode('custom');
    await rescanned.parseLink(sampleLink);
    await rescanned.toggleScan();
    expect(rescanned.rows[0].ip, '10.0.0.2');
    expect(rescanned.rows[0].stale, isTrue);
  });

  test('test these: improvement shows a positive delta, failure marks dead', () async {
    final engine = FakeEngine(
      scanResults: [ok('10.0.0.1', 200), ok('10.0.0.2', 300)],
      testOutcomes: {
        '10.0.0.1': ok('10.0.0.1', 150),
        '10.0.0.2': dead('10.0.0.2'),
      },
    );
    final c = make(engine);
    addTearDown(c.dispose);
    await c.parseLink(sampleLink);
    await c.toggleScan();
    c.setCount(2);
    await c.testThese();
    expect(engine.testCalls, 1);
    expect(c.tested['10.0.0.1']!.delayMs, 150);
    expect(c.tested['10.0.0.1']!.delta, 50);
    expect(c.tested['10.0.0.2']!.dead, isTrue);
    expect(c.testing, isFalse);
  });

  test('test these measures each unique IP once', () async {
    final engine = FakeEngine(
      scanResults: [ok('10.0.0.1', 90)],
      testOutcomes: {'10.0.0.1': ok('10.0.0.1', 90)},
    );
    final c = make(engine);
    addTearDown(c.dispose);
    await c.parseLink(sampleLink);
    await c.toggleScan();
    c.setMode('best');
    c.setCount(4);
    await c.testThese();
    expect(c.tested.keys.toList(), ['10.0.0.1']);
  });

  test('a new scan clears the test measurements', () async {
    final engine = FakeEngine(
      scanResults: [ok('10.0.0.1', 90)],
      testOutcomes: {'10.0.0.1': ok('10.0.0.1', 70)},
    );
    final c = make(engine);
    addTearDown(c.dispose);
    await c.parseLink(sampleLink);
    await c.toggleScan();
    await c.testThese();
    expect(c.tested, isNotEmpty);
    await c.toggleScan();
    expect(c.tested, isEmpty);
  });

  test('copy top 5 puts the top IPs on the clipboard with the Python label', () async {
    final engine = FakeEngine(scanResults: [ok('10.0.0.1', 90), ok('10.0.0.2', 120)]);
    final c = make(engine);
    addTearDown(c.dispose);
    final toasts = <String>[];
    c.toast = toasts.add;
    await c.parseLink(sampleLink);
    await c.toggleScan();
    await c.copyTop5();
    expect(clipboardText, '10.0.0.1\n10.0.0.2');
    expect(toasts.last, 'Top 2 IPs copied');
  });

  test('generate copies the built configs and keeps the name exactly', () async {
    final engine = FakeEngine(scanResults: [ok('10.0.0.1', 90), ok('10.0.0.2', 120)]);
    final c = make(engine);
    addTearDown(c.dispose);
    await c.parseLink(sampleLink);
    await c.toggleScan();
    c.setCount(2);
    await c.generateAndCopy();
    final lines = clipboardText!.split('\n');
    expect(lines.length, 2);
    final first = parse(lines[0]);
    expect(first, isNotNull);
    expect(first!.address, '10.0.0.1');
    expect(first.name, 'My Railway Config');
    expect(first.uuid, '11111111-2222-3333-4444-555555555555');
    expect(c.genFeedback, 'Copied 2');
  });

  test('copy row builds one config for that row IP', () async {
    final engine = FakeEngine(scanResults: [ok('10.0.0.1', 90), ok('10.0.0.2', 120)]);
    final c = make(engine);
    addTearDown(c.dispose);
    await c.parseLink(sampleLink);
    await c.toggleScan();
    c.setCount(2);
    await c.copyRowConfig(1);
    expect(parse(clipboardText!)!.address, '10.0.0.2');
    expect(c.copiedRow, 1);
  });

  test('configSummary shows the domain and the subnet', () async {
    final c = make(FakeEngine());
    addTearDown(c.dispose);
    expect(c.configSummary, 'No config loaded');
    await c.parseLink(sampleLink);
    expect(c.configSummary, 'fast-a.up.railway.app  ·  69.46.46.x');
  });
}
