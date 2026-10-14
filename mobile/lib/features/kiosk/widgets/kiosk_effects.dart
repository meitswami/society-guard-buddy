import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'kiosk_palette.dart';

/// Blurred colour blob (`rounded-full bg-x/NN blur-3xl`), optionally floating
/// like `animate-kiosk-float` (18 s loop: translate(40,-60) scale 1.12 → translate(-30,30) scale .92).
class KioskBlob extends StatefulWidget {
  const KioskBlob({super.key, required this.size, required this.color, this.float = false, this.delay = Duration.zero});

  final double size;
  final Color color;
  final bool float;

  /// Negative CSS `animation-delay` (start part-way through the loop).
  final Duration delay;

  @override
  State<KioskBlob> createState() => _KioskBlobState();
}

class _KioskBlobState extends State<KioskBlob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18));

  @override
  void initState() {
    super.initState();
    if (widget.float) {
      _c.value = (widget.delay.inMilliseconds / 18000) % 1;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Keyframes 0 / 33 / 66 / 100 % with ease-in-out per segment.
  ({double dx, double dy, double scale}) _frame(double t) {
    const k = [(0.0, 0.0, 0.0, 1.0), (0.33, 40.0, -60.0, 1.12), (0.66, -30.0, 30.0, 0.92), (1.0, 0.0, 0.0, 1.0)];
    for (var i = 0; i < k.length - 1; i++) {
      final a = k[i], b = k[i + 1];
      if (t <= b.$1) {
        final local = Curves.easeInOut.transform(((t - a.$1) / (b.$1 - a.$1)).clamp(0, 1));
        return (dx: _lerp(a.$2, b.$2, local), dy: _lerp(a.$3, b.$3, local), scale: _lerp(a.$4, b.$4, local));
      }
    }
    return (dx: 0, dy: 0, scale: 1);
  }

  @override
  Widget build(BuildContext context) {
    final blob = IgnorePointer(
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [widget.color, widget.color.withValues(alpha: 0)], stops: const [0.25, 1]),
        ),
      ),
    );
    if (!widget.float) return blob;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final f = _frame(_c.value);
        return Transform.translate(offset: Offset(f.dx, f.dy), child: Transform.scale(scale: f.scale, child: child));
      },
      child: blob,
    );
  }
}

/// Five bars bouncing like `animate-kiosk-wave` (0.9 s, staggered 0.12 s).
class KioskWaveBars extends StatefulWidget {
  const KioskWaveBars({super.key, this.color = KioskPalette.emerald300});

  final Color color;

  @override
  State<KioskWaveBars> createState() => _KioskWaveBarsState();
}

class _KioskWaveBarsState extends State<KioskWaveBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 5; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Builder(builder: (_) {
                final t = (_c.value - i * 0.12 / 0.9) % 1;
                // 0,100% → scaleY .35; 50% → 1 (ease-in-out)
                final s = 0.35 + 0.65 * (0.5 - 0.5 * math.cos(2 * math.pi * t));
                return Container(
                  width: 4,
                  height: 16 * s,
                  decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(999)),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// `animate-ping` ring behind the screensaver icon (scale 1 → 2, fade out, 1 s).
class KioskPing extends StatefulWidget {
  const KioskPing({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  State<KioskPing> createState() => _KioskPingState();
}

class _KioskPingState extends State<KioskPing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = const Cubic(0, 0, 0.2, 1).transform((_c.value / 0.75).clamp(0, 1));
        return Opacity(
          opacity: 1 - t,
          child: Transform.scale(
            scale: 1 + t,
            child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
          ),
        );
      },
    );
  }
}

/// `animate-pulse` (opacity 1 → .5 → 1, 2 s).
class KioskPulse extends StatefulWidget {
  const KioskPulse({super.key, required this.child});

  final Widget child;

  @override
  State<KioskPulse> createState() => _KioskPulseState();
}

class _KioskPulseState extends State<KioskPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Opacity(opacity: 0.75 + 0.25 * math.cos(2 * math.pi * _c.value), child: child),
        child: widget.child,
      );
}

/// `animate-kiosk-fade`: fade in + slide up 8 px over 0.5 s whenever [childKey] changes.
class KioskFadeIn extends StatelessWidget {
  const KioskFadeIn({super.key, required this.childKey, required this.child});

  final Object childKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(childKey),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (_, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: c)),
      child: child,
    );
  }
}
