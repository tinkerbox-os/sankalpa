import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sankalpa/app/theme/tokens.dart';

/// Soft, slow ambient decoration drawn behind a manifestation card's text.
///
/// All motifs render the same four-point sparkle from the brand logo
/// (`assets/brand/logo-symbol.svg` — long vertical/horizontal axes with
/// concave waists). The motif name controls density, scale, and whether
/// the sparkle has a soft halo around it:
///
///   - `sparkles`: many small twinkling sparkles, no halo. Calm "stardust".
///   - `stars`:    fewer mid-size sparkles with a faint halo. Quiet sky.
///   - `orbs`:     a few large sparkles with a strong soft halo and gentle
///                 drift. Reads as ambient light blooms; safe on lighter
///                 backgrounds.
///
/// Rendered with a single repaint-bounded `CustomPaint` driven by a
/// Ticker so the rest of the widget tree doesn't tear up every frame.
///
/// `color` should usually be the card's text colour — that's already
/// chosen for legibility against the backdrop, so it's a safe contrast
/// for decoration too.
class CardAmbientDecoration extends StatefulWidget {
  const CardAmbientDecoration({
    required this.kind,
    required this.color,
    this.intensity = 1.0,
    super.key,
  });

  final CardDecoration kind;
  final Color color;

  /// Multiplier on alpha. Use < 1.0 for tighter spaces (e.g. preview
  /// thumbnails) so the same motifs stay subtle.
  final double intensity;

  @override
  State<CardAmbientDecoration> createState() => _CardAmbientDecorationState();
}

class _CardAmbientDecorationState extends State<CardAmbientDecoration>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = _generate(widget.kind);
    _ticker = createTicker((d) {
      _t.value = d.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void didUpdateWidget(covariant CardAmbientDecoration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      _particles = _generate(widget.kind);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  static List<_Particle> _generate(CardDecoration kind) {
    // Deterministic seed per motif so particle layout is stable across
    // rebuilds — feels less "random" and more "designed".
    final rng = Random(kind.index * 7919 + 31);
    final n = switch (kind) {
      CardDecoration.sparkles => 22,
      CardDecoration.stars => 11,
      CardDecoration.orbs => 5,
      CardDecoration.none => 0,
    };
    return List<_Particle>.generate(n, (i) {
      return _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: switch (kind) {
          CardDecoration.sparkles => 2.5 + rng.nextDouble() * 3.0,
          CardDecoration.stars => 6.0 + rng.nextDouble() * 5.0,
          CardDecoration.orbs => 10.0 + rng.nextDouble() * 8.0,
          CardDecoration.none => 0,
        },
        // Slight rotation so they don't all look identical.
        rotation: (rng.nextDouble() - 0.5) * 0.6,
        phase: rng.nextDouble() * 2 * pi,
        period: 4.5 + rng.nextDouble() * 6.0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == CardDecoration.none) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: _t,
          builder: (context, t, _) {
            return CustomPaint(
              size: Size.infinite,
              painter: _DecorationPainter(
                kind: widget.kind,
                color: widget.color,
                intensity: widget.intensity,
                particles: _particles,
                t: t,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.rotation,
    required this.phase,
    required this.period,
  });

  final double x;
  final double y;
  final double size;
  final double rotation;
  final double phase;
  final double period;
}

class _DecorationPainter extends CustomPainter {
  _DecorationPainter({
    required this.kind,
    required this.color,
    required this.intensity,
    required this.particles,
    required this.t,
  });

  final CardDecoration kind;
  final Color color;
  final double intensity;
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final phase01 =
          (sin(t * 2 * pi / p.period + p.phase) + 1) / 2; // 0..1

      // Per-motif drift, alpha range, and halo behaviour. The shape is
      // the same four-point sparkle for everyone; we just dial up the
      // ambient glow as the motif gets larger.
      late final double alpha;
      late final double haloAlpha;
      late final double haloScale;
      var dx = 0.0;
      var dy = 0.0;
      switch (kind) {
        case CardDecoration.sparkles:
          alpha = 0.12 + 0.32 * phase01;
          haloAlpha = 0;
          haloScale = 0;
        case CardDecoration.stars:
          alpha = 0.16 + 0.42 * phase01;
          haloAlpha = 0.05 + 0.05 * phase01;
          haloScale = 2.6;
        case CardDecoration.orbs:
          // Orbs wander slowly around their anchor so the field feels
          // alive without the eye tracking any one bloom.
          dx = sin(t * 0.18 + p.phase) * 22;
          dy = cos(t * 0.13 + p.phase) * 16;
          alpha = 0.18 + 0.28 * phase01;
          haloAlpha = 0.08 + 0.06 * phase01;
          haloScale = 3.6;
        case CardDecoration.none:
          continue;
      }

      final center = Offset(p.x * size.width + dx, p.y * size.height + dy);

      if (haloAlpha > 0) {
        final haloRadius = p.size * haloScale;
        final haloPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(
                alpha: (haloAlpha * intensity).clamp(0.0, 1.0),
              ),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 1],
          ).createShader(
            Rect.fromCircle(center: center, radius: haloRadius),
          );
        canvas.drawCircle(center, haloRadius, haloPaint);
      }

      final fill = Paint()
        ..color = color.withValues(
          alpha: (alpha * intensity).clamp(0.0, 1.0),
        )
        ..isAntiAlias = true;

      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(p.rotation)
        ..drawPath(_sparklePath(p.size), fill)
        ..restore();
    }
  }

  /// Four-point sparkle centred on (0,0). Long vertical/horizontal axes
  /// with quadratic-bezier concave waists — the same silhouette as
  /// `assets/brand/logo-symbol.svg`.
  static Path _sparklePath(double r) {
    final w = r * 0.14; // waist control distance — smaller = pointier tips
    return Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(w, -w, r, 0)
      ..quadraticBezierTo(w, w, 0, r)
      ..quadraticBezierTo(-w, w, -r, 0)
      ..quadraticBezierTo(-w, -w, 0, -r)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _DecorationPainter old) =>
      old.t != t || old.kind != kind || old.color != color;
}

/// Subtle radial vignette. Pulled into its own widget so callers can
/// drop it onto any backdrop (theme card OR uploaded photo) for a
/// little extra depth around the edges.
class CardVignette extends StatelessWidget {
  const CardVignette({this.dark = true, super.key});

  /// When true, vignette darkens edges. When false, lightens them
  /// (useful on dark backgrounds where you want a centre glow).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final edge = dark ? Colors.black : Colors.white;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.95,
            stops: const [0.55, 1.0],
            colors: [
              edge.withValues(alpha: 0),
              edge.withValues(alpha: dark ? 0.18 : 0.06),
            ],
          ),
        ),
      ),
    );
  }
}
