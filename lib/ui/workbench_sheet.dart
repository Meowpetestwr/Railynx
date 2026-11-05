import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/controller.dart';
import '../app/latency.dart';
import '../app/look.dart';
import '../app/tokens.dart';
import '../app/workbench_model.dart';
import 'ip_picker_dialog.dart';
import 'widgets.dart';

/// The Build configs sheet (.sheet): the mockup's bottom sheet — grabber,
/// title + close, the gradient-thumb segmented control, explainer, the
/// Configs stepper, the amber shortage notice and the preview rows — with
/// the app's own extras kept inside the same look: the per-row latency
/// chips from Test these, the Custom picker, per-row copy, the Test these
/// button and the generated-configs panel.
class WorkbenchSheet extends StatelessWidget {
  const WorkbenchSheet({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          padding: EdgeInsets.fromLTRB(18, 10, 18, 22 + bottomInset),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF121735), Color(0xFF0A0D22)],
              stops: <double>[0, 0.6],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: Tokens.edge.withValues(alpha: 0.14)),
              left: BorderSide(color: Tokens.edge.withValues(alpha: 0.14)),
              right: BorderSide(color: Tokens.edge.withValues(alpha: 0.14)),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Tokens.indigo.withValues(alpha: 0.25),
                blurRadius: Look.richShadows ? 80 : 40,
                offset: const Offset(0, -30),
                spreadRadius: -20,
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => _SheetBody(controller: controller),
          ),
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Center(
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Tokens.edge.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Build configs',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: Tokens.ink,
                ),
              ),
            ),
            IconTap(
              icon: Icons.close,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (!c.hasResults)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Scan first to build configs.',
              style: TextStyle(fontSize: 13, color: Tokens.ink3),
            ),
          )
        else
          Flexible(child: _Workbench(controller: c)),
      ],
    );
  }
}

class _Workbench extends StatelessWidget {
  const _Workbench({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final modeIndex = modeOrder.indexOf(c.genMode);
    final showShortage = c.multiConfigs
        ? c.anyShortage
        : WorkbenchModel.shortage(
            mode: c.genMode,
            count: c.genCount,
            resultCount: c.results.length,
          );
    final shortageCount = c.multiConfigs ? c.shortageResultCount : c.results.length;
    // One scroll for everything above the action bar. The preview rows
    // used to sit in their own 240px box inside the sheet — with several
    // configs they were half-cut and needed a fiddly nested scroll (the
    // user's report). Now the rows take their natural height in the
    // sheet's single scroll view, and Test/Generate stay pinned below.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Segmented(
                  labels: const <String>['Top N', 'Best for all', 'Custom'],
                  index: modeIndex < 0 ? 0 : modeIndex,
                  onChanged: (i) => c.setMode(modeOrder[i]),
                ),
                const SizedBox(height: 10),
                Text(
                  modeExplainer[c.genMode] ?? '',
                  style: const TextStyle(fontSize: 13, height: 1.5, color: Tokens.ink2),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    const SectionLabel('Configs'),
                    const Spacer(),
                    if (c.multiConfigs)
                      Text(
                        '${c.parsedAll.length} pasted',
                        style: const TextStyle(
                          fontFamily: Tokens.monoFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Tokens.ink2,
                        ),
                      )
                    else
                      _Stepper(controller: c),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 16,
                  child: showShortage
                      ? Text(
                          WorkbenchModel.shortageText(shortageCount),
                          style: const TextStyle(fontSize: 12, color: Tokens.amber),
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < c.rows.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 8),
                  _PreviewRow(index: i, row: c.rows[i], controller: c),
                ],
                if (c.genText != null) ...<Widget>[
                  const SizedBox(height: 14),
                  const SectionLabel('Generated configs'),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Tokens.bg.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Tokens.edge.withValues(alpha: 0.14)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        c.genText!,
                        style: const TextStyle(
                          fontFamily: Tokens.monoFont,
                          fontSize: 11,
                          color: Tokens.ink2,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        TintButton(
          label: c.testing ? 'Testing…' : 'Test these',
          height: 50,
          radius: 18,
          onPressed: c.testing ? null : c.testThese,
        ),
        const SizedBox(height: 10),
        GradientButton(
          label: 'Generate & copy',
          onPressed: c.generateAndCopy,
        ),
      ],
    );
  }
}

/// .stepper: the dark tray with two 40px keys and the mono count.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Tokens.inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Tokens.edge.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          HoldRepeatButton(
            enabled: c.genCount > genMin,
            onStep: () => c.setCount(c.genCount - 1),
            child: const _StepKey(symbol: '−'),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            child: Text(
              '${c.genCount}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: Tokens.monoFont,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Tokens.ink,
              ),
            ),
          ),
          const SizedBox(width: 6),
          HoldRepeatButton(
            enabled: c.genCount < genMax,
            onStep: () => c.setCount(c.genCount + 1),
            child: const _StepKey(symbol: '+'),
          ),
        ],
      ),
    );
  }
}

class _StepKey extends StatelessWidget {
  const _StepKey({required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Tokens.glassSheen.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          symbol,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Tokens.ink),
        ),
      ),
    );
  }
}

/// One .pv preview row: index, the IP (or the Custom select box), the
/// changed dot / stale badge, the Test-these latency chip, and copy.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.index, required this.row, required this.controller});

  final int index;
  final ConfigRow row;
  final AppController controller;

  ChipInfo get _chip => controller.chipForRow(row);

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final copied = c.copiedRow == index;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Tokens.glassSheen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Tokens.edge.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 20,
            child: Text(
              (index + 1).toString().padLeft(2, '0'),
              style: const TextStyle(
                fontFamily: Tokens.monoFont,
                fontSize: 11,
                color: Tokens.ink3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (c.multiConfigs) ...<Widget>[
                  Text(
                    c.parsedAll[row.configIndex].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Tokens.ink3),
                  ),
                  const SizedBox(height: 3),
                ],
                _ipCell(context),
              ],
            ),
          ),
          if (row.changed) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: Tokens.pink, shape: BoxShape.circle),
            ),
          ],
          if (row.stale) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Tokens.amber.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'STALE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Tokens.amber,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          _ChipCell(info: _chip),
          const SizedBox(width: 8),
          IconTap(
            icon: copied ? Icons.check_rounded : Icons.copy_rounded,
            tooltip: 'Copy config #${index + 1}',
            onPressed: () => c.copyRowConfig(index),
          ),
        ],
      ),
    );
  }

  /// .pv .mono for plain rows; the .pv select box in Custom mode (opens the
  /// app's full IP picker, which carries the stale/delta logic).
  Widget _ipCell(BuildContext context) {
    final c = controller;
    final ip = row.ip;
    if (c.genMode == 'custom' && ip != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => IpPickerDialog(
              controller: c,
              rowIndex: index,
              results: c.multiConfigs ? c.resultsForConfig(row.configIndex) : null,
            ),
          ),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Tokens.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Tokens.edge.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    ip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: Tokens.monoFont,
                      fontSize: 13,
                      color: Tokens.ink,
                    ),
                  ),
                ),
                const Icon(Icons.expand_more, size: 16, color: Tokens.ink3),
              ],
            ),
          ),
        ),
      );
    }
    if (ip == null) {
      return const Text('—', style: TextStyle(color: Tokens.ink3));
    }
    return Text(
      ip,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: Tokens.monoFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Tokens.ink,
      ),
    );
  }
}

class _ChipCell extends StatelessWidget {
  const _ChipCell({required this.info});

  final ChipInfo info;

  @override
  Widget build(BuildContext context) {
    switch (info.kind) {
      case ChipKind.measuring:
        return const Pill(text: '···', color: Tokens.ink3);
      case ChipKind.dead:
        return const Pill(text: 'Dead', color: Tokens.poor, mono: false);
      case ChipKind.stale:
        return const Pill(text: 'stale', color: Tokens.slow, mono: false);
      case ChipKind.latency:
        final ms = info.ms ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (info.delta != 0)
              Text(
                WorkbenchModel.deltaLabel(info.delta),
                style: TextStyle(
                  fontFamily: Tokens.monoFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: info.delta > 0 ? Tokens.fast : Tokens.poor,
                ),
              ),
            if (info.delta != 0) const SizedBox(width: 6),
            Pill(text: '$ms ms', color: tierColor(tierFor(ms))),
          ],
        );
    }
  }
}
