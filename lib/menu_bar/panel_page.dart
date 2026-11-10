import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import '../ui/glass.dart';
import '../ui/menu_bar.dart';
import '../version.dart';
import '../widgets/repo_icon.dart';
import 'snapshot.dart';

/// The panel that opens when the mouse rests on the menu bar item.
///
/// It looks like a native menu: the material of macOS behind, no glass of the app. The window
/// is for the details, this is for the quick look and the one button that ships the work.
class MenuBarPanelPage extends StatefulWidget {
  const MenuBarPanelPage({super.key});

  @override
  State<MenuBarPanelPage> createState() => _MenuBarPanelPageState();
}

/// The colours that read on the panel, in the look the system is in.
class _Ink {
  const _Ink({
    required this.text,
    required this.muted,
    required this.hairline,
    required this.hover,
    required this.surface,
  });

  final Color text;
  final Color muted;
  final Color hairline;
  final Color hover;

  /// The panel draws its own surface, so the text always reads whatever is behind it.
  final Color surface;

  static const light = _Ink(
    text: Color(0xFF161B2C),
    muted: Color(0xFF4C5468),
    hairline: Color(0x1F1F2547),
    hover: Color(0x141F2547),
    surface: Color(0xF2F4F7FB),
  );

  static const dark = _Ink(
    text: Color(0xFFF4F6FB),
    muted: Color(0xFFC2C9DB),
    hairline: Color(0x2EFFFFFF),
    hover: Color(0x1FFFFFFF),
    surface: Color(0xF01E2230),
  );
}

class _MenuBarPanelPageState extends State<MenuBarPanelPage> {
  MenuBarSnapshot? _snapshot;
  bool _dark = false;

  /// How tall the panel may grow, told by the native side.
  double _maxHeight = 900;

  /// The header and the list are measured, so the panel can be as tall as the work needs.
  final _headerKey = GlobalKey();
  final _listKey = GlobalKey();

  _Ink get ink => _dark ? _Ink.dark : _Ink.light;

  @override
  void initState() {
    super.initState();
    MenuBarPanelBridge.listen(
      (map) {
        if (!mounted) return;
        setState(() => _snapshot = MenuBarSnapshot.fromJson(map));
        _reportHeight();
      },
      onAppearance: (name) {
        if (!mounted) return;
        setState(() => _dark = name == 'dark');
        _reportHeight();
      },
      onMaxHeight: (height) {
        if (!mounted) return;
        setState(() => _maxHeight = height);
        _reportHeight();
      },
    );
  }

  /// Tells the native side how tall the panel wants to be, so everything is seen without scrolling.
  void _reportHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final header = _headerKey.currentContext?.size?.height ?? 0;
      final list = _listKey.currentContext?.size?.height ?? 0;
      if (header == 0 || list == 0) return;
      // The 20 is the air around the card.
      MenuBarPanelBridge.resize(header + 12 + list + 34);
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final colors = ink;
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        // The panel is as tall as the work needs, but never taller than the screen.
        constraints: BoxConstraints(maxHeight: _maxHeight),
        child: Padding(
          // A little air around the card, so its own shadow has room.
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x553C1E50), blurRadius: 22, spreadRadius: -6, offset: Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                // The panel has its own surface: without it the text does not read.
                color: colors.surface,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    key: _headerKey,
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
                    child: Column(children: [
                      _Header(snapshot: snapshot, ink: colors),
                      const SizedBox(height: 12),
                      _ShipButton(snapshot: snapshot),
                    ]),
                  ),
                  // A little air between the information and the list.
                  const SizedBox(height: 12),
                  Flexible(child: _Body(snapshot: snapshot, ink: colors, listKey: _listKey)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.snapshot, required this.ink});

  final MenuBarSnapshot? snapshot;
  final _Ink ink;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = snapshot;
    return Row(children: [
      const LogoTile(size: 24),
      const SizedBox(width: 9),
      Flexible(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: Text('GIT Watcher', style: Txt.strong.copyWith(fontSize: 13, color: ink.text), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 5),
          Text('v$appVersion', style: Txt.muted.copyWith(fontSize: 10, color: ink.muted)),
        ]),
      ),
      const Spacer(),
      if (s != null) ...[
        if (s.dirty > 0) _Dot(count: s.dirty, color: Palette.orange, icon: Icons.difference_outlined, ink: ink),
        if (s.ahead > 0) _Dot(count: s.ahead, color: Palette.blue, icon: Icons.north_rounded, ink: ink),
        if (s.ciRunning > 0) _Dot(count: s.ciRunning, color: Palette.blue, icon: Icons.autorenew_rounded, ink: ink),
        if (s.ciFailed > 0) _Dot(count: s.ciFailed, color: Palette.red, icon: Icons.cancel_outlined, ink: ink),
        const SizedBox(width: 10),
      ],
      _IconButton(
        icon: Icons.refresh_rounded,
        tooltip: l.mbRefresh,
        ink: ink,
        onPressed: snapshot == null ? null : () => MenuBarPanelBridge.action('refresh'),
      ),
      const SizedBox(width: 2),
      _IconButton(
        icon: Icons.dashboard_customize_outlined,
        tooltip: l.mbOpenApp,
        ink: ink,
        onPressed: () => MenuBarPanelBridge.action('openWindow'),
      ),
      const SizedBox(width: 2),
      _IconButton(
        icon: Icons.power_settings_new_rounded,
        tooltip: l.mbQuit,
        ink: ink,
        onPressed: () => MenuBarPanelBridge.quit(),
      ),
    ]);
  }
}

/// A plain icon button, the way a native menu has them.
class _IconButton extends StatefulWidget {
  const _IconButton({required this.icon, required this.tooltip, required this.ink, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final _Ink ink;
  final VoidCallback? onPressed;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onPressed != null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: on ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover && on ? widget.ink.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(widget.icon, size: 15, color: on ? widget.ink.text : widget.ink.muted),
          ),
        ),
      ),
    );
  }
}

/// A count in a small coloured pill.
class _Dot extends StatelessWidget {
  const _Dot({required this.count, required this.color, required this.icon, required this.ink});

  final int count;
  final Color color;
  final IconData icon;
  final _Ink ink;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 5),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text('$count', style: Txt.strong.copyWith(fontSize: 11, color: color)),
        ]),
      );
}

/// The one button that matters: AI writes the message, commits and pushes everything waiting.
class _ShipButton extends StatelessWidget {
  const _ShipButton({required this.snapshot});

  final MenuBarSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = snapshot;
    final working = s?.busy ?? false;
    final work = s?.repos.where((repo) => repo.dirty || repo.ahead > 0).length ?? 0;
    return GlassButton(
      onPressed: work == 0 || working ? null : () => MenuBarPanelBridge.action('aiShipAll'),
      busy: working,
      icon: Icons.auto_awesome_rounded,
      label: l.mbAiShip,
      tone: GlassTone.rose,
      height: 32,
      radius: 9,
      expand: true,
      tooltip: l.mbShipAllTooltip,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.snapshot, required this.ink, required this.listKey});

  final MenuBarSnapshot? snapshot;
  final _Ink ink;
  final Key listKey;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = snapshot;
    if (s == null) {
      return const Center(child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.blue)));
    }
    if (s.repos.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.task_alt_rounded, size: 30, color: Palette.green),
          const SizedBox(height: 8),
          Text(l.mbAllClean, style: Txt.strong.copyWith(fontSize: 13, color: ink.text)),
          const SizedBox(height: 3),
          Text(l.mbAllCleanBody, style: Txt.muted.copyWith(fontSize: 11, color: ink.muted), textAlign: TextAlign.center),
        ]),
      );
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          key: listKey,
          children: [
            for (var i = 0; i < s.repos.length; i++)
              _RepoRow(repo: s.repos[i], ink: ink, last: i == s.repos.length - 1, busy: s.busy),
          ],
        ),
      ),
    );
  }
}

/// One repository: the work waiting, the buttons and the pipeline.
class _RepoRow extends StatelessWidget {
  const _RepoRow({required this.repo, required this.ink, required this.last, required this.busy});

  final MenuBarRepo repo;
  final _Ink ink;
  final bool last;

  /// The AI helper is at work somewhere, so no new work may be started.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canShip = repo.dirty && !busy;
    final canPush = repo.ahead > 0 && !busy;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => MenuBarPanelBridge.action('openRepo', path: repo.path),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: ink.hairline, width: .8))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              RepoIcon(name: repo.name, iconPath: repo.iconPath, size: 24),
              const SizedBox(width: 9),
              Expanded(child: _Title(repo: repo, ink: ink)),
              if (repo.ahead > 0)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.north_rounded, size: 12, color: Palette.blue),
                  const SizedBox(width: 1),
                  Text('${repo.ahead}', style: Txt.strong.copyWith(fontSize: 11.5, color: Palette.blue)),
                ]),
              if (repo.busy != null) ...[
                const SizedBox(width: 8),
                const SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: Palette.blue)),
              ],
            ]),
            if (canShip || canPush) ...[
              const SizedBox(height: 8),
              Row(children: [
                if (canShip)
                  Expanded(
                    child: GlassButton(
                      onPressed: () => MenuBarPanelBridge.action('aiShip', path: repo.path),
                      busy: repo.busy != null,
                      icon: Icons.auto_awesome_rounded,
                      label: l.mbAiCommit,
                      tone: GlassTone.rose,
                      height: 28,
                      radius: 8,
                      expand: true,
                      tooltip: l.mbAiCommitTooltip,
                    ),
                  ),
                if (canShip && canPush) const SizedBox(width: 6),
                if (canPush)
                  Expanded(
                    child: GlassButton(
                      onPressed: () => MenuBarPanelBridge.action('push', path: repo.path),
                      icon: Icons.north_rounded,
                      label: l.mbPush(repo.ahead),
                      tone: GlassTone.blue,
                      height: 28,
                      radius: 8,
                      expand: true,
                    ),
                  ),
              ]),
            ],
            // A pipeline that passed says nothing new, so only the ones at work or broken show.
            if (repo.ciText != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const SizedBox(width: 33),
                Icon(_ciIcon(repo.ciState), size: 12, color: _ciColor(repo.ciState)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(repo.ciText!, style: Txt.body.copyWith(fontSize: 11, color: ink.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (repo.ciRunning)
                  Text('${(repo.ciProgress * 100).round()}%', style: Txt.strong.copyWith(fontSize: 11, color: Palette.blue)),
              ]),
              if (repo.ciRunning) ...[
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 3,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: repo.ciProgress),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        color: Palette.blue,
                        backgroundColor: ink.hairline,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}

/// The name of the repository and what is waiting for it, on one line.
class _Title extends StatelessWidget {
  const _Title({required this.repo, required this.ink});

  final MenuBarRepo repo;
  final _Ink ink;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final small = Txt.body.copyWith(fontSize: 11, color: ink.muted);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: repo.name, style: Txt.strong.copyWith(fontSize: 12.5, color: ink.text)),
        TextSpan(text: '  ', style: small),
        TextSpan(
          text: repo.dirty ? '${repo.branch}*' : repo.branch,
          style: small.copyWith(color: repo.dirty ? Palette.orange : ink.muted),
        ),
        if (repo.dirty) ...[
          TextSpan(text: ' · ', style: small),
          TextSpan(text: l.mbFiles(repo.fileCount), style: small),
          if (repo.added > 0)
            TextSpan(text: ' +${repo.added}', style: small.copyWith(color: Palette.addedText, fontWeight: FontWeight.w500)),
          if (repo.deleted > 0)
            TextSpan(text: ' −${repo.deleted}', style: small.copyWith(color: Palette.deletedText, fontWeight: FontWeight.w500)),
        ] else if (repo.behind > 0) ...[
          TextSpan(text: ' · ', style: small),
          TextSpan(text: l.mbBehind(repo.behind), style: small.copyWith(color: Palette.amber)),
        ],
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

IconData _ciIcon(String state) => switch (state) {
      'queued' => Icons.hourglass_top_rounded,
      'running' => Icons.autorenew_rounded,
      'success' => Icons.check_circle_rounded,
      'failure' => Icons.cancel_rounded,
      'cancelled' => Icons.do_not_disturb_on_outlined,
      _ => Icons.radio_button_unchecked_rounded,
    };

Color _ciColor(String state) => switch (state) {
      'queued' => Palette.amber,
      'running' => Palette.blue,
      'success' => Palette.green,
      'failure' => Palette.red,
      _ => Palette.inkFaint,
    };
