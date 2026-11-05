import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railway_clean_ip_scanner/app/latency.dart';
import 'package:railway_clean_ip_scanner/app/tokens.dart';
import 'package:railway_clean_ip_scanner/ui/widgets.dart';

void main() {
  test('latency tiers match ui.html thresholds', () {
    expect(tierFor(0), LatencyTier.fast);
    expect(tierFor(119), LatencyTier.fast);
    expect(tierFor(120), LatencyTier.mid);
    expect(tierFor(299), LatencyTier.mid);
    expect(tierFor(300), LatencyTier.slow);
    expect(tierFor(600), LatencyTier.slow);
    expect(tierFor(601), LatencyTier.poor);
  });

  test('tier colours come from the ui.html tokens', () {
    expect(tierColor(LatencyTier.fast), Tokens.fast);
    expect(tierColor(LatencyTier.mid), Tokens.mid);
    expect(tierColor(LatencyTier.slow), Tokens.slow);
    expect(tierColor(LatencyTier.poor), Tokens.poor);
  });

  test('result bar width follows the ui.html formula with a 6 percent floor', () {
    expect(barFraction(0), closeTo(1.0, 1e-9));
    expect(barFraction(350), closeTo(0.5, 1e-9));
    expect(barFraction(700), closeTo(0.06, 1e-9));
    expect(barFraction(5000), closeTo(0.06, 1e-9));
  });

  testWidgets('IpText renders the octets and the dots', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: IpText('69.46.46.10')),
    ));
    final text = tester.widget<RichText>(
        find.descendant(of: find.byType(IpText), matching: find.byType(RichText)));
    expect(text.text.toPlainText(), '69.46.46.10');
  });

  testWidgets('LatencyChip shows ms and uses the tier colour', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: LatencyChip(ms: 250)),
    ));
    expect(find.text('250 ms'), findsOneWidget);
    final text = tester.widget<Text>(find.text('250 ms'));
    expect(text.style?.color, Tokens.mid);
  });

  testWidgets('AppSwitch toggles through its callback', (tester) async {
    var value = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => AppSwitch(
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(AppSwitch));
    await tester.pump();
    expect(value, isTrue);
  });

  group('OrbitArt spin discipline', () {
    testWidgets('no ticker runs when animation is off', (tester) async {
      await tester.pumpWidget(const OrbitArt(animated: false));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('ticker runs when on, and stops when switched off', (tester) async {
      await tester.pumpWidget(const OrbitArt(animated: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(const OrbitArt(animated: false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
