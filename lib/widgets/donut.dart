import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../theme.dart';

/// Ring of changed files by kind; a check when clean, or the commits waiting to be pushed.
class ChangeDonut extends StatelessWidget {
  const ChangeDonut({super.key, required this.counts, required this.ahead, this.size = 88});

  final Map<ChangeKind, int> counts;
  final int ahead;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    final Widget center;
    if (total > 0) {
      center = Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$total', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w300, color: Palette.ink, height: 1)),
        Text(total == 1 ? 'skrá' : 'skrár', style: Txt.muted.copyWith(fontSize: 10)),
      ]);
    } else if (ahead > 0) {
      center = Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.north_rounded, size: 15, color: Palette.blue),
        Text('$ahead', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w300, color: Palette.ink, height: 1)),
      ]);
    } else {
      center = const Icon(Icons.check_rounded, size: 30, color: Palette.green);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => CustomPaint(
        size: Size.square(size),
        painter: _DonutPainter(counts, total == 0 ? (ahead > 0 ? Palette.blue : Palette.green) : null, t),
        child: SizedBox.square(dimension: size, child: Center(child: child)),
      ),
      child: center,
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.counts, this.solid, this.progress);

  final Map<ChangeKind, int> counts;
  final Color? solid;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.5;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2 + 1);
    canvas.drawCircle(rect.center, arcRect.width / 2 + stroke / 2, Paint()..color = const Color(0x73FFFFFF));
    canvas.drawCircle(
      rect.center,
      arcRect.width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0x141F2547),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (solid != null) {
      canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * progress, false, paint..color = solid!);
      return;
    }

    final total = counts.values.fold(0, (a, b) => a + b);
    final gap = counts.length > 1 ? .16 : 0.0;
    var start = -math.pi / 2;
    for (final kind in ChangeKind.values) {
      final count = counts[kind] ?? 0;
      if (count == 0) continue;
      final sweep = 2 * math.pi * count / total * progress;
      canvas.drawArc(arcRect, start + gap / 2, math.max(sweep - gap, .02), false, paint..color = Palette.kind(kind));
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.progress != progress || old.solid != solid || old.counts != counts;
}
