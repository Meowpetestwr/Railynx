import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railway_clean_ip_scanner/app/controller.dart';
import 'package:railway_clean_ip_scanner/app/workbench_model.dart';
import 'package:railway_clean_ip_scanner/engine/vless_parser.dart';
import 'package:railway_clean_ip_scanner/engine/vless_scanner.dart';
import 'package:railway_clean_ip_scanner/ui/ip_picker_dialog.dart';

import '../fakes.dart';

const String uuidA = '11111111-2222-3333-4444-555555555555';
const String uuidB = '66666666-7777-4888-8999-000000000000';

String link(String uuid, String domain, String name, {String path = '%2Fws'}) {
  return 'vless://$uuid@$domain:443?encryption=none&security=tls&sni=$domain'
      '&type=ws&host=$domain&path=$path#${Uri.encodeComponent(name)}';
}

void main() {
  group('parseAll', () {
    test('returns every valid link in paste order, skipping junk', () {
      final text = <String>[
        link(uuidA, 'a.up.railway.app', 'First'),
        'not a link at all',
        link(uuidB, 'b.up.railway.app', 'Second'),
        'vless://broken',
        link(uuidA, 'a.up.railway.app', 'Third'),
      ].join('\n');
      final all = parseAll(text);
      expect(all.map((c) => c.name), <String>['First', 'Second', 'Third']);
      expect(all[1].uuid, uuidB);
    });
  });

  group('assignmentsMulti', () {
    final cfgA1 = parse(link(uuidA, 'a.up.railway.app', 'A1'))!;
    final cfgA2 = parse(link(uuidA, 'a.up.railway.app', 'A2'))!;
    final cfgB1 = parse(link(uuidB, 'b.up.railway.app', 'B1'))!;

    test('top mode rotates within each group only', () {
      final rows = WorkbenchModel.assignmentsMulti(
        configs: <VlessConfig>[cfgA1, cfgA2, cfgB1],
        resultsByGroup: <String, List<ScanResult>>{
          AppController.groupKeyOf(cfgA1): <ScanResult>[ok('69.46.46.1', 100), ok('69.46.46.2', 200)],
          AppController.groupKeyOf(cfgB1): <ScanResult>[ok('69.46.46.9', 50)],
        },
        groupKey: AppController.groupKeyOf,
        mode: 'top',
        custom: const <int, String>{},
      );
      expect(rows.map((r) => r.ip), <String?>['69.46.46.1', '69.46.46.2', '69.46.46.9']);
      expect(rows.map((r) => r.configIndex), <int>[0, 1, 2]);
    });

    test('best mode gives every config its own group fastest', () {
      final rows = WorkbenchModel.assignmentsMulti(
        configs: <VlessConfig>[cfgA1, cfgA2, cfgB1],
        resultsByGroup: <String, List<ScanResult>>{
          AppController.groupKeyOf(cfgA1): <ScanResult>[ok('69.46.46.1', 100), ok('69.46.46.2', 200)],
          AppController.groupKeyOf(cfgB1): <ScanResult>[ok('69.46.46.9', 50)],
        },
        groupKey: AppController.groupKeyOf,
        mode: 'best',
        custom: const <int, String>{},
      );
      expect(rows.map((r) => r.ip), <String?>['69.46.46.1', '69.46.46.1', '69.46.46.9']);
    });

    test('custom pick is validated against the row group only', () {
      final rows = WorkbenchModel.assignmentsMulti(
        configs: <VlessConfig>[cfgA1, cfgB1],
        resultsByGroup: <String, List<ScanResult>>{
          AppController.groupKeyOf(cfgA1): <ScanResult>[ok('69.46.46.1', 100)],
          AppController.groupKeyOf(cfgB1): <ScanResult>[ok('69.46.46.9', 50)],
        },
        groupKey: AppController.groupKeyOf,
        mode: 'custom',
        custom: const <int, String>{1: '69.46.46.1'},
      );
      // 69.46.46.1 is clean for A, unknown for B: stale for B's row.
      expect(rows[1].ip, '69.46.46.1');
      expect(rows[1].stale, isTrue);
      expect(rows[1].changed, isTrue);
    });
  });

  group('controller multi-config', () {
    test('two servers: scans each once, rows and links stay per-config', () async {
      final engine = FakeEngine(
        resultsByDomain: <String, List<ScanResult>>{
          'a.up.railway.app': <ScanResult>[ok('69.46.46.1', 100)],
          'b.up.railway.app': <ScanResult>[ok('69.46.46.9', 60)],
        },
      );
      final c = AppController(engine: engine);
      await c.parseLink(<String>[
        link(uuidA, 'a.up.railway.app', 'Alpha'),
        link(uuidB, 'b.up.railway.app', 'Beta'),
      ].join('\n'));
      expect(c.multiConfigs, isTrue);
      expect(c.multiGroups, isTrue);

      await c.toggleScan();
      expect(engine.scannedDomains, <String>['a.up.railway.app', 'b.up.railway.app']);
      expect(c.status, ScanStatus.done);
      expect(c.results.map((r) => r.ip), <String>['69.46.46.1']); // first group shown
      expect(c.rows.length, 2);
      expect(c.rows.map((r) => r.ip), <String?>['69.46.46.1', '69.46.46.9']);

      c.selectGroup(1);
      expect(c.results.map((r) => r.ip), <String>['69.46.46.9']);

      await c.generateAndCopy();
      final lines = c.genText!.split('\n');
      expect(lines.length, 2);
      expect(lines[0], contains('$uuidA@69.46.46.1:443'));
      expect(lines[0], contains('Alpha'));
      expect(lines[1], contains('$uuidB@69.46.46.9:443'));
      expect(lines[1], contains('Beta'));
      c.dispose();
    });

    test('same server twice: a single scan serves both configs', () async {
      final engine = FakeEngine(
        scanResults: <ScanResult>[ok('69.46.46.1', 100), ok('69.46.46.2', 200)],
      );
      final c = AppController(engine: engine);
      await c.parseLink(<String>[
        link(uuidA, 'a.up.railway.app', 'One'),
        link(uuidA, 'a.up.railway.app', 'Two'),
      ].join('\n'));
      expect(c.multiConfigs, isTrue);
      expect(c.multiGroups, isFalse);

      await c.toggleScan();
      expect(engine.scannedDomains.length, 1);
      expect(c.rows.map((r) => r.ip), <String?>['69.46.46.1', '69.46.46.2']);

      await c.generateAndCopy();
      final lines = c.genText!.split('\n');
      expect(lines.length, 2);
      expect(lines[0], contains('One'));
      expect(lines[1], contains('Two'));
      c.dispose();
    });

    test('best-for-all in multi uses each server fastest IP', () async {
      final engine = FakeEngine(
        resultsByDomain: <String, List<ScanResult>>{
          'a.up.railway.app': <ScanResult>[ok('69.46.46.3', 300), ok('69.46.46.1', 100)],
          'b.up.railway.app': <ScanResult>[ok('69.46.46.8', 80)],
        },
      );
      final c = AppController(engine: engine);
      await c.parseLink(<String>[
        link(uuidA, 'a.up.railway.app', 'Alpha'),
        link(uuidA, 'a.up.railway.app', 'Alpha2'),
        link(uuidB, 'b.up.railway.app', 'Beta'),
      ].join('\n'));
      await c.toggleScan();
      c.setMode('best');
      expect(c.rows.map((r) => r.ip), <String?>['69.46.46.1', '69.46.46.1', '69.46.46.8']);
      c.dispose();
    });
  });

  group('manual IP entry (fix 4)', () {
    testWidgets('unknown IP errors, found IP is accepted', (tester) async {
      final c = AppController(
        engine: FakeEngine(scanResults: <ScanResult>[ok('69.46.46.7', 120)]),
      );
      await c.parseLink(sampleLink);
      await c.toggleScan();
      c.setMode('custom');

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: IpPickerDialog(controller: c, rowIndex: 0))),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), '69.46.46.99');
      await tester.tap(find.text('Use'));
      await tester.pump();
      expect(find.text('That IP is not among the clean IPs found.'), findsOneWidget);
      expect(c.custom[0], isNull);

      await tester.enterText(find.byType(TextField), '999.1.1.1');
      await tester.tap(find.text('Use'));
      await tester.pump();
      expect(find.text('Enter a valid IPv4 address.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '69.46.46.7');
      await tester.tap(find.text('Use'));
      await tester.pump();
      expect(c.custom[0], '69.46.46.7');
      c.dispose();
    });
  });
}
