import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../app/tokens.dart';
import 'widgets.dart';

/// Appearance & performance settings (the user's design): the full
/// aurora look stays the default, and anyone whose phone struggles can
/// trade effects for speed — either through a preset or switch by
/// switch. Everything applies live and persists across restarts.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Tokens.bg,
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: AuroraBackdrop(
                  animated: c.animatedAurora,
                  showBlobs: c.fxBlobs,
                  showWashes: c.fxWashes,
                  halfRes: c.fxHalfRes,
                ),
              ),
              SafeArea(
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Row(
                        children: <Widget>[
                          IconTap(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Appearance',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: Tokens.ink,
                              ),
                            ),
                          ),
                          if (c.uiPreset == 'custom')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Tokens.amber.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Tokens.amber.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'Custom',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Tokens.amber,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        children: <Widget>[
                          const SectionLabel('Preset'),
                          const SizedBox(height: 10),
                          _PresetCard(
                            title: 'Original',
                            subtitle: 'The full design as it was before any optimisation — every effect rich.',
                            selected: c.uiPreset == 'original',
                            onTap: () => c.applyPreset('original'),
                          ),
                          const SizedBox(height: 10),
                          _PresetCard(
                            title: 'Balanced',
                            subtitle: 'Aurora stays, drawn the cheap way — light shadows, stepped glows, half-res lights.',
                            selected: c.uiPreset == 'balanced',
                            onTap: () => c.applyPreset('balanced'),
                          ),
                          const SizedBox(height: 10),
                          _PresetCard(
                            title: 'Performance',
                            subtitle: 'Plain and fast — no aurora, no blur, no motion.',
                            selected: c.uiPreset == 'performance',
                            onTap: () => c.applyPreset('performance'),
                          ),
                          const SizedBox(height: 22),
                          const SectionLabel('Customize'),
                          const SizedBox(height: 10),
                          GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Column(
                              children: <Widget>[
                                _ToggleRow(
                                  title: 'Animated aurora',
                                  subtitle: 'The slow drift of the aurora lights. Off freezes the backdrop — the GPU stops redrawing it.',
                                  value: c.animatedAurora,
                                  onChanged: (v) => c.setFx(anim: v),
                                ),
                                const _RowDivider(),
                                _ToggleRow(
                                  title: 'Aurora lights',
                                  subtitle: 'The three coloured light discs. A full-screen layer — turning them off is the biggest single saving.',
                                  value: c.fxBlobs,
                                  onChanged: (v) => c.setFx(blobs: v),
                                ),
                                const _RowDivider(),
                                _ToggleRow(
                                  title: 'Half-resolution aurora',
                                  subtitle: 'Draws the aurora at a quarter of the pixels and upscales it. Same soft picture, far less GPU work.',
                                  value: c.fxHalfRes,
                                  onChanged: (v) => c.setFx(halfRes: v),
                                ),
                                const _RowDivider(),
                                _ToggleRow(
                                  title: 'Light washes',
                                  subtitle: 'The soft colour washes behind the cards. Pure decoration; off is cheaper.',
                                  value: c.fxWashes,
                                  onChanged: (v) => c.setFx(washes: v),
                                ),
                                const _RowDivider(),
                                _ToggleRow(
                                  title: 'Rich shadows',
                                  subtitle: 'The deep, soft shadows of the original look. Off uses light shadows — flatter, faster to draw.',
                                  value: c.fxRichShadows,
                                  onChanged: (v) => c.setFx(richShadows: v),
                                ),
                                const _RowDivider(),
                                _ToggleRow(
                                  title: 'Blurred glow',
                                  subtitle: 'Real blur filters for glows like the ring halo. Off paints a stepped halo instead — reads the same, no blur pass.',
                                  value: c.fxGlowBlur,
                                  onChanged: (v) => c.setFx(glowBlur: v),
                                ),
                                const _RowDivider(),
                                _ToggleRow(
                                  title: 'Dock blur',
                                  subtitle: 'Blur behind the bottom bar. One of the priciest effects while scrolling.',
                                  value: c.fxDockBlur,
                                  onChanged: (v) => c.setFx(dockBlur: v),
                                ),
                                const _RowDivider(),
                                _ToggleRow(
                                  title: 'Button flow',
                                  subtitle: 'The moving gradient on the scan button while a scan runs.',
                                  value: c.fxButtonFlow,
                                  onChanged: (v) => c.setFx(buttonFlow: v),
                                ),
                                const _RowDivider(),
                                _ToggleRow(
                                  title: 'Ring glow',
                                  subtitle: 'The halo around the scan ring, and its gradient arc. Off draws the arc in one flat colour.',
                                  value: c.fxRingGlow,
                                  onChanged: (v) => c.setFx(ringGlow: v),
                                ),
                                const _RowDivider(),
                                _ToggleRow(
                                  title: 'Row animations',
                                  subtitle: 'Result rows fade and rise as they arrive.',
                                  value: c.fxRowAnimations,
                                  onChanged: (v) => c.setFx(rowAnimations: v),
                                ),
                                const _RowDivider(),
                                _ToggleRow(
                                  title: 'Lightweight rows',
                                  subtitle: 'Drops each result row\u2019s extra layer once its entrance ends. Invisible — pure speed with many results.',
                                  value: c.fxLiteRows,
                                  onChanged: (v) => c.setFx(liteRows: v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          const SectionLabel('Frame rate'),
                          const SizedBox(height: 10),
                          GlassCard(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text(
                                  'Refresh-rate cap',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Tokens.ink),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Caps this app\u2019s display refresh rate on Android. Lower can feel steadier on weak GPUs and is kinder to the battery; Max uses your screen\u2019s full rate.',
                                  style: TextStyle(fontSize: 12, height: 1.4, color: Tokens.ink3),
                                ),
                                const SizedBox(height: 12),
                                Segmented(
                                  labels: const <String>['Max', '60', '30'],
                                  index: c.fpsLimit == 60 ? 1 : (c.fpsLimit == 30 ? 2 : 0),
                                  onChanged: (i) => c.setFpsLimit(i == 1 ? 60 : (i == 2 ? 30 : 0)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Changes apply instantly and are saved automatically.',
                            style: TextStyle(fontSize: 12, height: 1.5, color: Tokens.ink3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? Tokens.teal.withValues(alpha: 0.10)
                : Tokens.glassSheen.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? Tokens.teal.withValues(alpha: 0.55)
                  : Tokens.edge.withValues(alpha: 0.14),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: selected ? Tokens.teal : Tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12.5, height: 1.4, color: Tokens.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 22,
                color: selected ? Tokens.teal : Tokens.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Tokens.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: Tokens.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: Tokens.edge.withValues(alpha: 0.08));
  }
}
