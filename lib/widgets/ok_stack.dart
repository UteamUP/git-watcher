import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../state/watcher_controller.dart';
import '../theme.dart';
import '../ui/glass.dart';
import 'repo_icon.dart';

/// The repos with nothing to do, stacked into one card like a pile of glass.
/// [open] runs 0 (stacked) to 1 (fanned out into the grid).
class OkStack extends StatelessWidget {
  const OkStack({super.key, required this.repos, required this.open, required this.onTap});

  final List<RepoState> repos;
  final Animation<double> open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedBuilder(
            animation: open,
            builder: (context, _) {
              final t = Curves.easeOutCubic.transform(open.value);
              return Stack(clipBehavior: Clip.none, children: [
                // Two cards peeking out below the front one; they slide in behind it as the pile opens.
                for (final (depth, inset) in const [(2, 26.0), (1, 13.0)])
                  Positioned(
                    left: inset,
                    right: inset,
                    top: 0,
                    bottom: 24,
                    child: Opacity(
                      opacity: (1 - t) * (depth == 1 ? .9 : .7),
                      child: Transform.translate(
                        offset: Offset(0, depth * 12 * (1 - t)),
                        child: const GlassPanel(radius: 24, tint: Color(0x4DFFFFFF), child: SizedBox.expand()),
                      ),
                    ),
                  ),
                Positioned(left: 0, right: 0, top: 0, bottom: 24 * (1 - t), child: _Front(repos: repos, t: t)),
              ]);
            },
          ),
        ),
      );
}

class _Front extends StatelessWidget {
  const _Front({required this.repos, required this.t});

  final List<RepoState> repos;
  final double t;

  @override
  Widget build(BuildContext context) {
    const shown = 11;
    final l = context.l10n;
    return GlassPanel(
      radius: 24,
      tint: const Color(0x66FFFFFF),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const GlassTile(size: 42, child: Icon(Icons.done_all_rounded, color: Palette.green, size: 24)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.topAllGood, style: Txt.title),
              const SizedBox(height: 2),
              Text(l.topNothingToShip(repos.length), style: Txt.muted, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Expanded(
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final repo in repos.take(shown))
                  Tooltip(message: repo.name, child: RepoIcon(name: repo.name, iconPath: repo.iconPath, size: 36)),
                if (repos.length > shown)
                  GlassTile(size: 36, child: Text('+${repos.length - shown}', style: Txt.strong.copyWith(fontSize: 12))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x8078DC96), Color(0x5C1CA050)],
            ),
            border: Border.all(color: const Color(0x4D16803F), width: .8),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(t < .5 ? l.topShowAll(repos.length) : l.topStackAgain,
                style: Txt.button.copyWith(color: const Color(0xFF063A1C))),
            const SizedBox(width: 6),
            Transform.rotate(
              angle: math.pi * t,
              child: const Icon(Icons.expand_more_rounded, size: 20, color: Color(0xFF063A1C)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Lets a card fan out of the pile: each one fades, drops and grows in a little after the one before.
class Unstack extends StatelessWidget {
  const Unstack({super.key, required this.open, required this.index, required this.count, required this.child});

  final Animation<double> open;
  final int index;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: open,
        child: child,
        builder: (context, child) {
          final start = count <= 1 ? 0.0 : .45 * index / (count - 1);
          final t = Curves.easeOutCubic.transform(((open.value - start) / (1 - start)).clamp(0.0, 1.0));
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, -36 * (1 - t)),
              child: Transform.scale(scale: .9 + .1 * t, child: child),
            ),
          );
        },
      );
}
