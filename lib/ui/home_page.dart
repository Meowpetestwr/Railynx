import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/controller.dart';
import '../app/latency.dart';
import '../app/look.dart';
import '../app/tokens.dart';
import '../engine/vless_scanner.dart';
import 'settings_page.dart';
import 'widgets.dart';
import 'workbench_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _toastText;
  bool _toastShown = false;
  Timer? _toastTimer;
  String? _lastParseHint;
  bool? _lastParseHintOk;
  bool _sheetOpen = false;

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.toast = _showToast;
    c.addListener(_watchParseHint);
  }

  @override
  void dispose() {
    c.removeListener(_watchParseHint);
    if (c.toast == _showToast) {
      c.toast = null;
    }
    _toastTimer?.cancel();
    super.dispose();
  }

  /// The HTML gives parse feedback as a toast ("Config parsed"), never as a
  /// line of text. Translate the controller's parse hint into that toast.
  void _watchParseHint() {
    final hint = c.parseHint;
    if (hint == null) {
      return;
    }
    if (hint == _lastParseHint && c.parseHintOk == _lastParseHintOk) {
      return;
    }
    _lastParseHint = hint;
    _lastParseHintOk = c.parseHintOk;
    _showToast(c.parseHintOk ? 'Config parsed' : hint);
  }

  void _showToast(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _toastText = message;
      _toastShown = true;
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _toastShown = false);
      }
    });
  }

  Future<void> _openWorkbench() async {
    if (!c.hasAnyResults) {
      _showToast('Scan first to build configs');
      return;
    }
    // The backdrop drift pauses while the sheet is up: it is mostly
    // covered anyway, and its repaints compete with the sheet's scroll.
    setState(() => _sheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WorkbenchSheet(controller: c),
    );
    if (mounted) {
      setState(() => _sheetOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.bg,
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.enter, control: true): () => c.toggleScan(),
          const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): () =>
              c.generateAndCopy(),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                // The backdrop must listen for itself: it is built outside
                // the content's ListenableBuilder, so without this, look
                // changes made in Settings never reached the home page.
                child: ListenableBuilder(
                  listenable: c,
                  builder: (context, _) => AuroraBackdrop(
                    animated: c.animatedAurora && !_sheetOpen,
                    showBlobs: c.fxBlobs,
                    showWashes: c.fxWashes,
                    halfRes: c.fxHalfRes,
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListenableBuilder(
                      listenable: c,
                      builder: (context, _) => ListView(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 128),
                        children: <Widget>[
                          _Header(
                            controller: c,
                            onSettings: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SettingsPage(controller: c),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          RepaintBoundary(child: _ConfigCard(controller: c)),
                          const SizedBox(height: 16),
                          RepaintBoundary(child: _ScanHero(controller: c)),
                          const SizedBox(height: 16),
                          _ResultsSection(controller: c, onToast: _showToast),
                          const SizedBox(height: 20),
                          const _Footer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _Dock(controller: c, onBuild: _openWorkbench),
                  ),
                ),
              ),
              // .toast: light pill, bottom 112, slides/fades in.
              Positioned(
                left: 0,
                right: 0,
                bottom: 112,
                child: IgnorePointer(
                  child: AnimatedSlide(
                    offset: _toastShown ? Offset.zero : const Offset(0, 0.35),
                    duration: const Duration(milliseconds: 350),
                    curve: const Cubic(0.22, 1, 0.36, 1),
                    child: AnimatedOpacity(
                      opacity: _toastShown ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: Tokens.toastBg,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: Look.richShadows ? 30 : 16,
                                offset: const Offset(0, 12),
                                spreadRadius: -6,
                              ),
                            ],
                          ),
                          child: Text(
                            _toastText ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Tokens.toastInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onSettings});

  final AppController controller;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final desktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('assets/cat.png', width: 38, height: 38, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Railynx',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: Tokens.ink,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Twilight edition',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: Tokens.ink3,
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(controller: c),
          const SizedBox(width: 10),
          IconTap(
            icon: Icons.settings_rounded,
            tooltip: 'Appearance settings',
            onPressed: onSettings,
          ),
          if (desktop) ...<Widget>[
            const SizedBox(width: 10),
            IconTap(
              icon: Icons.close,
              tooltip: 'Close app',
              onPressed: () => SystemNavigator.pop(),
            ),
          ],
        ],
      ),
    );
  }
}

/// The .pill status: Ready / Scanning / Paused / Done · N clean, with the
/// dot (pulsing while live, glowing when done).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final (String text, Widget dot) = switch (c.status) {
      ScanStatus.scanning => ('Scanning', const _PulsingDot()),
      ScanStatus.done => (
          'Done · ${c.results.length} clean',
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Tokens.fast,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: Tokens.fast, blurRadius: 10),
              ],
            ),
          ),
        ),
      ScanStatus.stopped => (
          'Paused',
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Tokens.ink3, shape: BoxShape.circle),
          ),
        ),
      ScanStatus.error => (
          'Error',
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Tokens.poor, shape: BoxShape.circle),
          ),
        ),
      ScanStatus.idle => (
          'Ready',
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Tokens.ink3, shape: BoxShape.circle),
          ),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Tokens.glassSheen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Tokens.edge.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          dot,
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Tokens.ink2),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        final spread = 9 * t;
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Tokens.teal,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Tokens.teal.withValues(alpha: 0.55 * (1 - t)),
                blurRadius: 0,
                spreadRadius: spread,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: c.toggleConfigOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SectionLabel('Config'),
                          const SizedBox(height: 6),
                          Text(
                            c.configSummary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: Tokens.monoFont,
                              fontSize: 13,
                              color: Tokens.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Tokens.glassSheen.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Tokens.edge.withValues(alpha: 0.14)),
                      ),
                      child: AnimatedRotation(
                        turns: c.configOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 350),
                        curve: const Cubic(0.22, 1, 0.36, 1),
                        child: const Icon(Icons.expand_more, size: 18, color: Tokens.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: const Cubic(0.22, 1, 0.36, 1),
            alignment: Alignment.topCenter,
            child: c.configOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: _ConfigBody(controller: c),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ConfigBody extends StatelessWidget {
  const _ConfigBody({required this.controller});

  final AppController controller;

  Widget _field(String label, TextEditingController ctl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Tokens.ink2),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctl,
          decoration: _inputDecoration(hint),
          style: const TextStyle(fontFamily: Tokens.monoFont, fontSize: 13, color: Tokens.ink),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: Tokens.monoFont, fontSize: 13, color: Tokens.placeholder),
      isDense: true,
      filled: true,
      fillColor: Tokens.inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Tokens.inputEdge),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Tokens.inputEdge),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Tokens.teal.withValues(alpha: 0.7)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    // The dimming Opacity exists only while scanning; at full opacity
    // it would leave a permanent compositing layer over the whole card.
    final column = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: c.link,
                    onChanged: c.onLinkChanged,
                    decoration: _inputDecoration('Paste a vless:// link'),
                    style: const TextStyle(
                      fontFamily: Tokens.monoFont,
                      fontSize: 13,
                      color: Tokens.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ChipButton(label: 'Paste', onPressed: c.pasteFromClipboard),
              ],
            ),
            const SizedBox(height: 14),
            _field('Domain / SNI', c.domain, 'fast-production-xxxx.up.railway.app'),
            const SizedBox(height: 10),
            _field('UUID', c.uuid, '3f2c9a1e-7b44-4d0e-9a1f-…'),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _field('Path', c.path, '/ws')),
                const SizedBox(width: 10),
                Expanded(child: _field('Subnet', c.subnet, '69.46.46.')),
              ],
            ),
          ],
        );
    return AbsorbPointer(
      absorbing: c.scanning,
      child: c.scanning ? Opacity(opacity: 0.6, child: column) : column,
    );
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final total = AppController.scanTotal;

    final String cur;
    if (c.scanning) {
      cur = c.currentIp ?? '—';
    } else if (c.status == ScanStatus.done) {
      cur = '';
    } else {
      cur = c.currentIp ?? '—';
    }

    final String hint;
    if (c.statusIsError) {
      hint = c.statusLine;
    } else if (c.status == ScanStatus.idle &&
        c.statusLine != 'Ready — paste a VLESS config to begin.') {
      // A controller prompt (e.g. "paste a config first") takes the hint slot.
      hint = c.statusLine;
    } else if (c.scanning) {
      hint = c.scanGroupNote.isEmpty
          ? 'Testing each IP through a real tunnel…'
          : '${c.scanGroupNote} — testing each IP through a real tunnel…';
    } else if (c.status == ScanStatus.done) {
      hint = 'Tap any IP to copy it';
    } else if (c.status == ScanStatus.stopped) {
      hint = 'Stopped — tap resume to continue';
    } else {
      hint = 'Paste a config, then start the scan';
    }

    final String label;
    if (c.scanning) {
      label = 'Stop';
    } else if (c.status == ScanStatus.done) {
      label = 'Scan again';
    } else if (c.status == ScanStatus.stopped && c.scanned > 0) {
      label = 'Resume scan';
    } else {
      label = 'Start scan';
    }

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        children: <Widget>[
          ScanRing(
            glow: c.fxRingGlow,
            glowBlur: c.fxGlowBlur,
            fraction: c.scanned / total,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${c.scanned}',
                  style: const TextStyle(
                    fontFamily: Tokens.monoFont,
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1,
                    height: 1,
                    color: Tokens.ink,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'of $total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: Tokens.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 18,
            child: Text(
              cur,
              style: const TextStyle(
                fontFamily: Tokens.monoFont,
                fontSize: 13,
                color: Tokens.ink2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 18,
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Tokens.ink3),
            ),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: label,
            icon: c.scanning ? Icons.stop_rounded : Icons.play_arrow_rounded,
            live: c.scanning && c.fxButtonFlow,
            onPressed: c.toggleScan,
          ),
        ],
      ),
    );
  }
}

/// Results section (HTML order): section head, then the empty card or the
/// best card + the ranked rows (best excluded — it has its own card).
class _ResultsSection extends StatefulWidget {
  const _ResultsSection({required this.controller, required this.onToast});

  final AppController controller;
  final void Function(String) onToast;

  @override
  State<_ResultsSection> createState() => _ResultsSectionState();
}

class _ResultsSectionState extends State<_ResultsSection> {
  final Set<String> _seen = <String>{};

  AppController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final results = c.results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: <Widget>[
              const Text(
                'Clean IPs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: Tokens.ink,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Tokens.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Tokens.teal.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${results.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: Tokens.monoFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Tokens.teal,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'by delay',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Tokens.ink3),
              ),
            ],
          ),
        ),
        if (c.multiGroups) ...<Widget>[
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (var i = 0; i < c.groupLeaders.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 8),
                  _GroupChip(
                    label: c.groupLeaders[i].name,
                    selected: i == c.activeGroup,
                    onTap: () => c.selectGroup(i),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (results.isEmpty)
          _EmptyCard(animated: c.animatedAurora)
        else ...<Widget>[
          _BestCard(controller: c, onToast: widget.onToast),
          const SizedBox(height: 14),
          for (var i = 1; i < results.length; i++) ...<Widget>[
            if (i > 1) const SizedBox(height: 10),
            _ResultRow(
              rank: i + 1,
              result: results[i],
              fresh: c.fxRowAnimations && !_seen.contains(results[i].ip),
              controller: c,
              onToast: widget.onToast,
            ),
          ],
        ],
        // Mark every current IP as seen so only genuinely new rows animate.
        Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _seen.addAll(results.map((r) => r.ip));
            });
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

/// One server-group chip in the results header (multi-config mode):
/// tapping switches the visible result list to that server's scan.
class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? Tokens.teal.withValues(alpha: 0.16)
                : Tokens.glassSheen.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Tokens.teal.withValues(alpha: 0.5)
                  : Tokens.edge.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Tokens.teal : Tokens.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.animated});

  final bool animated;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 26),
      // Full width, or the column hugs the left edge of the card at its
      // widest child's width and the empty state sits visibly off-center.
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: <Widget>[
            OrbitArt(animated: animated),
          SizedBox(height: 14),
          Text(
            'No clean IPs yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Tokens.ink),
          ),
          SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 260),
              child: Text(
                'Start a scan. Every IP is verified through a real tunnel, and the fastest ones appear here, ranked.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.6, color: Tokens.ink3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestCard extends StatelessWidget {
  const _BestCard({required this.controller, required this.onToast});

  final AppController controller;
  final void Function(String) onToast;

  @override
  Widget build(BuildContext context) {
    final top = controller.results.first;
    final tier = tierColor(tierFor(top.delayMs));
    final copied = controller.copiedIp == top.ip;
    return Stack(
      children: <Widget>[
        GlassCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SectionLabel('Fastest'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Tokens.fast,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Tokens.fast.withValues(alpha: 0.6),
                          blurRadius: Look.richShadows ? 18 : 8,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: const Text(
                      'TOP PICK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Tokens.crownInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                top.ip,
                style: const TextStyle(
                  fontFamily: Tokens.monoFont,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: Tokens.ink,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text.rich(TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: '${top.delayMs}',
                              style: TextStyle(
                                fontFamily: Tokens.monoFont,
                                fontSize: 40,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1,
                                height: 1,
                                color: tier,
                                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                              ),
                            ),
                            const TextSpan(
                              text: ' ms',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Tokens.ink3),
                            ),
                          ],
                        )),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            for (var i = 0; i < 3; i++) ...<Widget>[
                              if (i > 0) const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: tier,
                                  shape: BoxShape.circle,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(color: tier, blurRadius: 8, spreadRadius: -1),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(width: 10),
                            const Text(
                              'STABLE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: Tokens.ink3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        controller.copyIp(top.ip);
                        onToast('Best IP copied');
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Tokens.glassSheen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Tokens.edge.withValues(alpha: 0.14)),
                        ),
                        child: Icon(
                          copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 16,
                          color: copied ? Tokens.fast : Tokens.ink2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // .best::before — the gradient border ring at .55 opacity.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _GradientBorderPainter()),
          ),
        ),
      ],
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(0.5), const Radius.circular(26));
    final faded = LinearGradient(
      begin: Tokens.grad.begin,
      end: Tokens.grad.end,
      colors: <Color>[for (final col in Tokens.grad.colors) col.withValues(alpha: 0.55)],
      stops: Tokens.grad.stops,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = faded.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GradientBorderPainter old) => false;
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.rank,
    required this.result,
    required this.fresh,
    required this.controller,
    required this.onToast,
  });

  final int rank;
  final ScanResult result;
  final bool fresh;
  final AppController controller;
  final void Function(String) onToast;

  @override
  Widget build(BuildContext context) {
    final tier = tierColor(tierFor(result.delayMs));
    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          controller.copyIp(result.ip);
          onToast('Copied ${result.ip}');
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 13, 14, 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.94, -0.34),
              end: const Alignment(0.94, 0.34),
              colors: <Color>[
                Tokens.glassSheen.withValues(alpha: 0.08),
                Tokens.glassSheen.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Tokens.edge.withValues(alpha: 0.09)),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 26,
                child: Text(
                  rank.toString().padLeft(2, '0'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: Tokens.monoFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Tokens.ink3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      result.ip,
                      style: const TextStyle(
                        fontFamily: Tokens.monoFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Tokens.ink,
                        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 9),
                    _LatencyBar(ms: result.delayMs, color: tier),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text.rich(TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '${result.delayMs}',
                    style: TextStyle(
                      fontFamily: Tokens.monoFont,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: tier,
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                  const TextSpan(
                    text: ' ms',
                    style: TextStyle(fontSize: 11, color: Tokens.ink3),
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
    if (!fresh) {
      return row;
    }
    // .row.in — rowIn .5s: fade + rise 10px + settle from .98 scale.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: const Cubic(0.22, 1, 0.36, 1),
      // Lightweight rows (a Settings switch, on by default): once the
      // entrance settles, return the row BARE — leaving an Opacity(1)
      // + two Transforms wrapped around every row forever costs a
      // compositing layer per row (60 results = 60 layers). Off keeps
      // the original always-wrapped rows; the picture is identical.
      builder: (context, v, child) => Look.liteRows && v >= 1 && child != null
          ? child
          : Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - v)),
          child: Transform.scale(scale: 0.98 + 0.02 * v, child: child),
        ),
      ),
      child: row,
    );
  }
}

/// The latency bar: 4px track + the tier-coloured fill with its glow
/// (box-shadow 0 0 10px -2px in the mockup — a wider, fainter underlay
/// here, which reads identically and costs no filter).
class _LatencyBar extends StatelessWidget {
  const _LatencyBar({required this.ms, required this.color});

  final int ms;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Tokens.edge.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: barFraction(ms),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: <BoxShadow>[
              BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 10, spreadRadius: -2),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        Text(
          'Railynx',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Tokens.ink2),
        ),
        SizedBox(height: 4),
        Text(
          'Real checks, ranked results, ready-to-paste configs.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Tokens.ink3),
        ),
      ],
    );
  }
}

/// The .dock: a bottom strip with the fade-to-navy gradient and the one
/// backdrop blur in the app (content scrolls under it, so here the blur is
/// real), Copy top 5 ghost + Build configs gradient at 1fr / 1.25fr.
class _Dock extends StatelessWidget {
  const _Dock({required this.controller, required this.onBuild});

  final AppController controller;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bar = Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 14 + bottomInset),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Tokens.bg.withValues(alpha: 0),
                Tokens.bg.withValues(alpha: 0.88),
                Tokens.bg.withValues(alpha: 0.96),
              ],
              stops: const <double>[0, 0.36, 1],
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 100,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => TintButton(
                    label: 'Copy top 5',
                    onPressed: controller.hasResults ? controller.copyTop5 : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 125,
                child: GradientButton(
                  label: 'Build configs',
                  icon: Icons.add_rounded,
                  height: 54,
                  radius: 19,
                  fontSize: 15,
                  onPressed: onBuild,
                ),
              ),
            ],
          ),
    );
    // The blur is one of the priciest effects on weak GPUs; the
    // Performance preset drops it (same gradient bar, no filter).
    return ClipRect(
      child: controller.fxDockBlur
          ? BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: bar,
            )
          : bar,
    );
  }
}
