import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/latency.dart';
import '../app/look.dart';
import '../app/tokens.dart';

/// Glass panel, the HTML's .glass rule: a 160deg sheen gradient
/// (rgba(148,175,220,.10) -> .03), the .14 edge border, radius 26, an inset
/// top highlight and the deep soft shadow.
///
/// No BackdropFilter on purpose: the backdrop behind the cards is itself a
/// soft gradient field with no sharp detail, so the browser's blur(22px)
/// over it is visually identical to the unblurred backdrop — while stacking
/// a live backdrop filter under every card is the classic scroll-jank
/// source on mid-range phones. The look stays, the cost goes.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        // Rich shadows (the default, original look): the deep soft
        // shadow. The light set is the Settings trade-off — a gaussian
        // shadow this size is real raster work on weak GPUs.
        boxShadow: <BoxShadow>[
          if (Look.richShadows)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 44,
              offset: const Offset(0, 20),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-0.94, -0.34),
                    end: const Alignment(0.94, 0.34),
                    colors: <Color>[
                      Tokens.glassSheen.withValues(alpha: 0.10),
                      Tokens.glassSheen.withValues(alpha: 0.03),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Tokens.edge.withValues(alpha: 0.14)),
              ),
              child: child,
            ),
            // inset 0 1px 0 rgba(255,255,255,.07)
            Positioned(
              top: 0,
              left: 26,
              right: 26,
              child: Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small uppercase label used across the page (.label).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: Tokens.ink3,
      ),
    );
  }
}

/// Coloured pill with monospace text: latency chips and badges.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, required this.color, this.mono = true});

  final String text;
  final Color color;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: mono ? Tokens.monoFont : null,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Latency chip, coloured by tier (fast/mid/slow/poor).
class LatencyChip extends StatelessWidget {
  const LatencyChip({super.key, required this.ms});

  final int ms;

  @override
  Widget build(BuildContext context) {
    return Pill(text: '$ms ms', color: tierColor(tierFor(ms)));
  }
}

/// IP address with dimmed dots, as in ui.html.
class IpText extends StatelessWidget {
  const IpText(this.ip, {super.key, this.size = 14, this.color = Tokens.ink});

  final String ip;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final octets = ip.split('.');
    final spans = <InlineSpan>[];
    for (var i = 0; i < octets.length; i++) {
      if (i > 0) {
        spans.add(TextSpan(
          text: '.',
          style: TextStyle(color: Tokens.ink3.withValues(alpha: 0.7)),
        ));
      }
      spans.add(TextSpan(text: octets[i]));
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: Tokens.monoFont,
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        children: spans,
      ),
    );
  }
}

/// Gradient call-to-action button (.btn-grad): h58, radius 20, the aurora
/// gradient, dark ink text, the pink/teal lift shadow. In its [live] state
/// (scanning) it turns coral with the gradient flowing across it, exactly
/// like the mockup's .btn-grad.live.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 58,
    this.radius = 20,
    this.fontSize = 16,
    this.live = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double radius;
  final double fontSize;
  final bool live;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.live) {
      // Ping-pong, never a hard restart: a plain repeat() snapped the
      // gradient back to its first frame every cycle (the user's "the
      // colours suddenly reset" report). Reversing makes the flow
      // continuous — there is no wrap point at all.
      _flow.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GradientButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.live && !_flow.isAnimating) {
      _flow.repeat(reverse: true);
    } else if (!widget.live && _flow.isAnimating) {
      _flow.stop();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final radius = BorderRadius.circular(widget.radius);
    // No Opacity layer at full opacity (invisible plumbing, always
    // on). The shadows follow the Rich shadows switch: original =
    // the two coloured glows; light = one modest shadow — a gaussian
    // shadow this size re-rasterises on every repaint of the button,
    // which while scanning is every animation tick.
    final button = Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            if (Look.richShadows) ...<BoxShadow>[
              BoxShadow(
                color: (widget.live ? Tokens.poor : Tokens.pink).withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 12),
                spreadRadius: -8,
              ),
              BoxShadow(
                color: Tokens.teal.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
                spreadRadius: -4,
              ),
            ] else
              BoxShadow(
                color: (widget.live ? Tokens.poor : Tokens.pink).withValues(alpha: 0.38),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: -6,
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onPressed,
            child: AnimatedBuilder(
            animation: _flow,
            builder: (context, _) {
              // .btn-grad.live: the same 200%-wide gradient, flowing.
              final shift = widget.live ? -1 + 2 * _flow.value : 0.0;
              final gradient = LinearGradient(
                begin: Alignment(shift - 1, -0.35),
                end: Alignment(shift + 1, 0.35),
                colors: Tokens.ringColors,
                stops: Tokens.ringStops,
              );
              return Ink(
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: radius,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.icon != null) ...<Widget>[
                        Icon(widget.icon, size: 18, color: Tokens.onGradient),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: Tokens.onGradient,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            ),
          ),
        ),
      );
    if (!enabled) {
      return Opacity(opacity: 0.4, child: button);
    }
    return button;
  }
}

/// Ghost or soft action button, matching .btn-ghost (h54, radius 19).
class TintButton extends StatelessWidget {
  const TintButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tint = Tokens.ink2,
    this.strong = false,
    this.height = 54,
    this.radius = 19,
    this.fontSize = 14,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color tint;
  final bool strong;
  final double height;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ghost = tint == Tokens.ink2 && !strong;
    final body = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onPressed,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: ghost
                  ? Tokens.glassSheen.withValues(alpha: 0.09)
                  : tint.withValues(alpha: strong ? 0.16 : 0.09),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: ghost
                    ? Tokens.edge.withValues(alpha: 0.18)
                    : tint.withValues(alpha: strong ? 0.35 : 0.18),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: Tokens.ink,
                ),
              ),
            ),
          ),
        ),
      );
    if (!enabled) {
      return Opacity(opacity: 0.4, child: body);
    }
    return body;
  }
}

/// The .chip button from the config card (h46, radius 14): Paste.
class ChipButton extends StatelessWidget {
  const ChipButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Tokens.glassSheen.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Tokens.edge.withValues(alpha: 0.14)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Tokens.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only rounded button (.copy / .close / .chev family, 36px default).
class IconTap extends StatelessWidget {
  const IconTap({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 36,
    this.iconSize = 16,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Tokens.glassSheen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Tokens.edge.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, size: iconSize, color: Tokens.ink2),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Switch with the ui.html look (teal track when on).
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? Tokens.teal.withValues(alpha: 0.7) : Tokens.edge.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(color: Tokens.ink, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// Button that fires once on press and repeats while held (the stepper).
class HoldRepeatButton extends StatefulWidget {
  const HoldRepeatButton({super.key, required this.child, required this.onStep, this.enabled = true});

  final Widget child;
  final VoidCallback onStep;
  final bool enabled;

  @override
  State<HoldRepeatButton> createState() => _HoldRepeatButtonState();
}

class _HoldRepeatButtonState extends State<HoldRepeatButton> {
  Timer? _delay;
  Timer? _repeat;

  void _stop() {
    _delay?.cancel();
    _repeat?.cancel();
    _delay = null;
    _repeat = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        if (!widget.enabled) {
          return;
        }
        widget.onStep();
        _delay = Timer(const Duration(milliseconds: 350), () {
          _repeat = Timer.periodic(const Duration(milliseconds: 70), (_) => widget.onStep());
        });
      },
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: widget.enabled ? widget.child : Opacity(opacity: 0.35, child: widget.child),
    );
  }
}

/// Segmented control with a sliding gradient thumb (.seg): Top N /
/// Best for all / Custom.
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Tokens.inputBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Tokens.edge.withValues(alpha: 0.14)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: const Duration(milliseconds: 450),
                curve: const Cubic(0.22, 1, 0.36, 1),
                left: index * segWidth,
                top: 0,
                bottom: 0,
                width: segWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: Tokens.grad,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Tokens.indigo.withValues(alpha: 0.55),
                        blurRadius: Look.richShadows ? 18 : 10,
                        offset: const Offset(0, 6),
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onChanged(i),
                        child: Center(
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: i == index ? Tokens.onGradient : Tokens.ink2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Circular progress ring with the aurora sweep stroke (.ring): r52 of a
/// 120 viewBox, stroke 7, the #gradStroke ramp, round caps, and the indigo
/// drop-shadow under the arc. [fraction] is animated, so the arc glides.
class ScanRing extends StatelessWidget {
  const ScanRing({
    super.key,
    required this.fraction,
    required this.child,
    this.size = 176,
    this.glow = true,
    this.glowBlur = true,
  });

  final double fraction;
  final Widget child;
  final double size;

  /// Settings switch: false drops the halo underlay and draws the
  /// arc as one flat colour (the ramp colour of the head position).
  final bool glow;

  /// Blurred glows switch, forwarded to the painter.
  final bool glowBlur;

  @override
  Widget build(BuildContext context) {
    final target = fraction.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: target),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(value, glow: glow, glowBlur: glowBlur),
              ),
              child,
            ],
          );
        },
      ),
    );
  }
}

/// The ramp colour at sweep position [t] (0 = arc start, 1 = full circle),
/// from the mockup's #gradStroke stops.
Color ringRampColor(double t) {
  final colors = Tokens.ringColors;
  final stops = Tokens.ringStops;
  if (t <= stops.first) {
    return colors.first;
  }
  for (var i = 1; i < stops.length; i++) {
    if (t <= stops[i]) {
      final span = stops[i] - stops[i - 1];
      final local = span == 0 ? 0.0 : (t - stops[i - 1]) / span;
      return Color.lerp(colors[i - 1], colors[i], local)!;
    }
  }
  return colors.last;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, {this.glow = true, this.glowBlur = true});

  final double fraction;
  final bool glow;

  /// Blurred glows switch: true paints the original MaskFilter.blur
  /// halo; false paints the stepped halo (no filter pass).
  final bool glowBlur;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 120;
    final stroke = 7 * scale;
    final radius = 52 * scale;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Tokens.edge.withValues(alpha: 0.09),
    );
    if (fraction <= 0) {
      return;
    }

    final sweep = 2 * math.pi * fraction;
    Shader shader() => const SweepGradient(
          colors: Tokens.ringColors,
          stops: Tokens.ringStops,
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect);

    // Butt caps on purpose: a round cap at the arc's start reaches BACK
    // past the top into the sweep's final degrees and picks up the amber
    // end of the ramp there — on the phone the tiny finished arc showed
    // an orange tip at its start (the user's report). The round head is
    // drawn separately as a dot in the ramp colour of the head position,
    // so amber can only ever appear as the circle nears completion.
    //
    // drop-shadow(0 0 8px rgba(129,140,248,.45)) in the mockup. Two
    // forms, chosen by the Blurred glows switch: the original is a
    // MaskFilter.blur pass over the ring canvas on every repaint
    // (rich, and the pricier one — the overlay readings put the
    // raster thread at 25-28ms); the light form is two wider, fainter
    // unblurred strokes, a stepped halo that reads the same at phone
    // scale. Skipped entirely when the ring glow setting is off; the
    // arc then paints flat.
    if (glow && glowBlur) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = stroke + 3 * scale
          ..color = Tokens.indigo.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * scale),
      );
    } else if (glow) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = stroke + 9 * scale
          ..color = Tokens.indigo.withValues(alpha: 0.10),
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = stroke + 4 * scale
          ..color = Tokens.indigo.withValues(alpha: 0.20),
      );
    }
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      glow
          ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.butt
            ..strokeWidth = stroke
            ..shader = shader())
          : (Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.butt
            ..strokeWidth = stroke
            ..color = ringRampColor(fraction)),
    );
    // The round head, in the exact ramp colour of its position.
    final headAngle = -math.pi / 2 + sweep;
    final head = center + Offset(math.cos(headAngle), math.sin(headAngle)) * radius;
    canvas.drawCircle(head, stroke / 2, Paint()..color = ringRampColor(fraction));
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.glow != glow || old.glowBlur != glowBlur;
}

/// The empty-state orbit from the mockup: a dashed outer circle, a plain
/// inner circle, the gradient core, and two dots circling at 14s and -9s.
///
/// The spin follows [animated] (the aurora-animation switch): this used
/// to repeat unconditionally, which meant the app scheduled frames
/// forever in its most common state — the idle empty card — even with
/// every effect switched off. Off now means a static single frame.
class OrbitArt extends StatefulWidget {
  const OrbitArt({super.key, this.size = 112, this.animated = true});

  final double size;
  final bool animated;

  @override
  State<OrbitArt> createState() => _OrbitArtState();
}

class _OrbitArtState extends State<OrbitArt> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(OrbitArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.animated) {
      if (!_spin.isAnimating) {
        _spin.repeat();
      }
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _OrbitPainter(_spin.value),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 112;
    final center = Offset(56 * s, 56 * s);

    // Dashed outer circle: dash 3, gap 6 (in 112 units).
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * s
      ..color = Tokens.edge.withValues(alpha: 0.12);
    const circumference = 2 * math.pi * 50;
    const dashLen = 3.0;
    const gapLen = 6.0;
    var travelled = 0.0;
    while (travelled < circumference) {
      final startAngle = (travelled / 50) - math.pi / 2;
      final sweepAngle = dashLen / 50;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 50 * s),
        startAngle,
        sweepAngle,
        false,
        dashPaint,
      );
      travelled += dashLen + gapLen;
    }

    canvas.drawCircle(
      center,
      34 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * s
        ..color = Tokens.edge.withValues(alpha: 0.16),
    );

    // Gradient core, r12, opacity .9.
    final coreRect = Rect.fromCircle(center: center, radius: 12 * s);
    canvas.drawCircle(
      center,
      12 * s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Tokens.teal, Tokens.indigo, Tokens.pink],
          stops: <double>[0, 0.6, 1],
        ).createShader(coreRect)
        ..color = Colors.white.withValues(alpha: 0.9),
    );

    // Orbiting dots: teal r4 on r50 (14s), pink r3 on r34 (reverse, 9s).
    final a1 = -math.pi / 2 + 2 * math.pi * t;
    canvas.drawCircle(
      center + Offset(math.cos(a1), math.sin(a1)) * 50 * s,
      4 * s,
      Paint()..color = Tokens.teal,
    );
    final a2 = -2 * math.pi * ((t * 14 / 9) % 1);
    canvas.drawCircle(
      center + Offset(math.cos(a2), math.sin(a2)) * 34 * s,
      3 * s,
      Paint()..color = Tokens.pink,
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}

/// The Shafaq backdrop: the mockup's four layered radial washes plus the
/// three drifting aurora blobs. Two painters on purpose:
///  * [_WashPainter] is fully static (base + washes), so its
///    RepaintBoundary rasterises it once and it is never repainted —
///    before, one combined painter redrew all seven gradients on every
///    animation tick, a real cost on mid-range phones.
///  * [_BlobPainter] carries only the three drifting blobs.
/// Blob repaint stays throttled to ~30fps (the drift runs 20-29s; nothing
/// on screen can tell the difference).
class AuroraBackdrop extends StatefulWidget {
  const AuroraBackdrop({
    super.key,
    required this.animated,
    this.showBlobs = true,
    this.showWashes = true,
    this.halfRes = false,
  });

  final bool animated;

  /// Settings switches: the drifting aurora discs and the static light
  /// washes can each be turned off (Performance preset turns off both,
  /// leaving the plain background colour).
  final bool showBlobs;
  final bool showWashes;

  /// Settings switch: rasterise the blob layer at half resolution and
  /// upscale it (a quarter of the pixels, the same soft picture).
  final bool halfRes;

  @override
  State<AuroraBackdrop> createState() => _AuroraBackdropState();
}

class _AuroraBackdropState extends State<AuroraBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 290),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AuroraBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.animated) {
      if (!_clock.isAnimating) {
        _clock.repeat();
      }
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(
            child: CustomPaint(painter: _WashPainter(washes: widget.showWashes), size: Size.infinite),
          ),
          if (widget.showBlobs)
            AnimatedBuilder(
              animation: _clock,
              builder: (context, _) {
                final seconds = widget.animated ? _clock.value * 290 : 0.0;
                final step = (seconds * 30).floor() / 30;
                if (!widget.halfRes) {
                  // The original: full-resolution rasterisation.
                  return RepaintBoundary(
                    child: CustomPaint(
                      painter: _BlobPainter(step),
                      size: Size.infinite,
                    ),
                  );
                }
                // Half-resolution rasterisation: the blobs are soft
                // gradients, so a quarter of the pixels carries the
                // same picture. The boundary rasterises at half size;
                // the FittedBox upscales the cached texture.
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final full = constraints.biggest;
                    return FittedBox(
                      fit: BoxFit.fill,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: full.width / 2,
                        height: full.height / 2,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _HalfResPainter(_BlobPainter(step), full),
                            size: Size(full.width / 2, full.height / 2),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Paints [inner] (which works in full-size coordinates) into a
/// half-size canvas, for the backdrop's half-resolution blob layer.
class _HalfResPainter extends CustomPainter {
  _HalfResPainter(this.inner, this.fullSize);

  final _BlobPainter inner;
  final Size fullSize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(0.5);
    inner.paint(canvas, fullSize);
  }

  @override
  bool shouldRepaint(_HalfResPainter old) =>
      old.inner.seconds != inner.seconds || old.fullSize != fullSize;
}

/// ease-in-out triangle wave for one blob's drift cycle.
double _driftPhase(double seconds, double period) {
  final x = (seconds % period) / period;
  final tri = x < 0.5 ? x * 2 : 2 - x * 2;
  return tri * tri * (3 - 2 * tri);
}

/// Base colour + the four .screen washes. Static — painted once.
class _WashPainter extends CustomPainter {
  _WashPainter({this.washes = true});

  /// False = background colour only (Performance preset).
  final bool washes;
  void _wash(Canvas canvas, Offset center, double rx, double ry, Color color, double fadeEnd) {
    final rect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[color, color.withValues(alpha: 0)],
        stops: <double>[0, fadeEnd],
      ).createShader(rect);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, ry / rx);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawCircle(center, rx, paint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = Tokens.bg);
    if (!washes) {
      return;
    }

    // .screen background washes (values straight from the CSS).
    _wash(canvas, Offset(w * 0.5, -h * 0.12), w * 1.2, h * 0.55, Tokens.indigo.withValues(alpha: 0.38), 0.62);
    _wash(canvas, Offset(-w * 0.10, h * 0.28), w * 0.9, h * 0.45, Tokens.teal.withValues(alpha: 0.22), 0.62);
    _wash(canvas, Offset(w * 1.10, h * 0.48), w * 0.9, h * 0.55, Tokens.pink.withValues(alpha: 0.20), 0.62);
    _wash(canvas, Offset(w * 0.5, h * 1.12), w * 1.3, h * 0.42, Tokens.amber.withValues(alpha: 0.30), 0.70);
  }

  @override
  bool shouldRepaint(_WashPainter old) => old.washes != washes;
}

/// The three .aurora blobs: solid discs under CSS blur(72px) at opacity
/// .42. A blurred solid disc is NOT a centre-out gradient disc — the blur
/// keeps a broad bright plateau and spreads light ~two sigmas past the
/// disc's edge. The old gradient-disc approximation (.42 -> .20 -> 0 over
/// the bare disc radius) threw away most of that light, which is why the
/// app looked darker than the HTML (the user's report). The falloff below
/// follows the blurred-disc shape instead: plateau, then a soft tail,
/// over a radius widened by the blur spread.
class _BlobPainter extends CustomPainter {
  _BlobPainter(this.seconds);

  final double seconds;

  void _blob(Canvas canvas, Offset center, double r, Color color, double phase) {
    final dx = 42 * phase;
    final dy = -34 * phase;
    final scaled = r * (1 + 0.14 * phase);
    final c = center + Offset(dx, dy);
    const spread = 64.0; // ~2 sigma of the 72px CSS blur
    final drawRadius = scaled + spread;
    final plateau = (scaled - 30) / drawRadius;
    final fall = (scaled + 25) / drawRadius;
    final rect = Rect.fromCircle(center: c, radius: drawRadius);
    canvas.drawCircle(
      c,
      drawRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.40),
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0),
          ],
          stops: <double>[0, plateau, fall, 1],
        ).createShader(rect),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // .aurora blobs (blur(72px) discs, drift 20s / 25s / 29s).
    _blob(canvas, Offset(-90 + 130, -70 + 130), 130, Tokens.teal, _driftPhase(seconds, 20));
    _blob(canvas, Offset(w + 120 - 150, 230 + 150), 150, Tokens.indigo, _driftPhase(seconds + 7, 25));
    _blob(canvas, Offset(30 + 120, h + 130 - 120), 120, Tokens.pink, _driftPhase(seconds + 13, 29));
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.seconds != seconds;
}
