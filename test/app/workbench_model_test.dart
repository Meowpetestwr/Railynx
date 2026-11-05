import 'package:railway_clean_ip_scanner/app/workbench_model.dart';
import 'package:test/test.dart';

import '../fakes.dart';

void main() {
  final results = [ok('10.0.0.1', 80), ok('10.0.0.2', 150), ok('10.0.0.3', 400)];

  test('top mode gives each row the next-best IP and wraps', () {
    final rows = WorkbenchModel.assignments(
      count: 5, mode: 'top', results: results, custom: const <int, String>{});
    expect(rows.map((r) => r.ip).toList(),
        ['10.0.0.1', '10.0.0.2', '10.0.0.3', '10.0.0.1', '10.0.0.2']);
    expect(rows.any((r) => r.changed || r.stale), isFalse);
  });

  test('best mode uses the fastest IP for every row', () {
    final rows = WorkbenchModel.assignments(
      count: 4, mode: 'best', results: results, custom: const <int, String>{});
    expect(rows.every((r) => r.ip == '10.0.0.1'), isTrue);
  });

  test('custom pick is marked changed when it differs from the auto pick', () {
    final rows = WorkbenchModel.assignments(
      count: 3, mode: 'custom', results: results, custom: const <int, String>{1: '10.0.0.3'});
    expect(rows[1].ip, '10.0.0.3');
    expect(rows[1].changed, isTrue);
    expect(rows[1].stale, isFalse);
    expect(rows[0].changed, isFalse);
  });

  test('custom pick equal to the auto pick is not marked changed', () {
    final rows = WorkbenchModel.assignments(
      count: 2, mode: 'custom', results: results, custom: const <int, String>{1: '10.0.0.2'});
    expect(rows[1].changed, isFalse);
  });

  test('a custom pick missing from the latest scan is stale', () {
    final rows = WorkbenchModel.assignments(
      count: 1, mode: 'custom', results: results, custom: const <int, String>{0: '9.9.9.9'});
    expect(rows[0].ip, '9.9.9.9');
    expect(rows[0].stale, isTrue);
  });

  test('no results gives empty rows', () {
    final rows = WorkbenchModel.assignments(
      count: 2, mode: 'top', results: const [], custom: const <int, String>{});
    expect(rows.every((r) => r.ip == null), isTrue);
  });

  test('shortage notice only for top mode when count exceeds results', () {
    expect(WorkbenchModel.shortage(mode: 'top', count: 5, resultCount: 3), isTrue);
    expect(WorkbenchModel.shortage(mode: 'top', count: 3, resultCount: 3), isFalse);
    expect(WorkbenchModel.shortage(mode: 'best', count: 5, resultCount: 3), isFalse);
    expect(WorkbenchModel.shortage(mode: 'top', count: 5, resultCount: 0), isFalse);
    expect(WorkbenchModel.shortageText(3), 'Only 3 clean IPs found, so some configs will share one.');
  });

  test('uniqueIps keeps first-seen order and drops nulls and repeats', () {
    final rows = WorkbenchModel.assignments(
      count: 5, mode: 'top', results: results, custom: const <int, String>{});
    expect(WorkbenchModel.uniqueIps(rows), ['10.0.0.1', '10.0.0.2', '10.0.0.3']);
  });

  test('measured delta is previous minus new, zero without a previous value', () {
    expect(WorkbenchModel.measured(200, 150).delta, 50);
    expect(WorkbenchModel.measured(100, 150).delta, -50);
    expect(WorkbenchModel.measured(null, 150).delta, 0);
  });

  test('delta labels: down arrow for improvement, up arrow for regression', () {
    expect(WorkbenchModel.deltaLabel(12), '↓12');
    expect(WorkbenchModel.deltaLabel(-7), '↑7');
  });

  test('previous delay prefers the last good test over the scan', () {
    final delays = {'10.0.0.1': 80};
    expect(WorkbenchModel.previousDelay('10.0.0.1', const {}, delays), 80);
    expect(
      WorkbenchModel.previousDelay('10.0.0.1',
          const {'10.0.0.1': Tested(delayMs: 60)}, delays),
      60,
    );
    expect(
      WorkbenchModel.previousDelay('10.0.0.1',
          const {'10.0.0.1': Tested(dead: true)}, delays),
      80,
    );
  });

  test('chip for a row: measuring, dead, stale, latency with delta', () {
    final tested = <String, Tested>{
      'a': const Tested(delayMs: 90, delta: 15),
      'b': const Tested(dead: true),
    };
    final delays = {'a': 105, 'c': 200};
    ChipInfo chip(String? ip, {bool testing = false, Set<String> testingIps = const {}}) {
      return WorkbenchModel.chipFor(
        ip: ip, tested: tested, delays: delays, testingIps: testingIps, testing: testing);
    }

    expect(chip(null).kind, ChipKind.stale);
    expect(chip('a', testing: true, testingIps: {'a'}).kind, ChipKind.measuring);
    expect(chip('b').kind, ChipKind.dead);
    expect(chip('a').kind, ChipKind.latency);
    expect(chip('a').ms, 90);
    expect(chip('a').delta, 15);
    expect(chip('c').kind, ChipKind.latency);
    expect(chip('c').ms, 200);
    expect(chip('z').kind, ChipKind.stale);
  });

  test('clamping constants match ui.html', () {
    expect(genMin, 1);
    expect(genMax, 20);
    expect(defaultGenCount, 5);
    expect(modeOrder, ['top', 'best', 'custom']);
  });
}
