import 'package:flutter/material.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../state/watcher_controller.dart';
import '../theme.dart';
import '../ui/feedback.dart';
import '../ui/glass.dart';
import 'donut.dart';
import 'helper_panel.dart';
import 'menus.dart';
import 'repo_icon.dart';

class RepoCard extends StatelessWidget {
  const RepoCard({super.key, required this.controller, required this.repo, required this.onOpen});

  final WatcherController controller;
  final RepoState repo;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final idle = repo.busy == null;
    final dirty = repo.dirty;
    return GlassPanel(
      radius: 24,
      tint: const Color(0x5CFFFFFF),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Header(controller: controller, repo: repo, onOpen: onOpen),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: Row(children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onOpen,
                child: Tooltip(
                  message: l.cardViewChanges,
                  child: ChangeDonut(counts: repo.status?.counts ?? const {}, ahead: repo.ahead),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _Legend(repo)),
          ]),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: Color(0x121F2547)),
        const SizedBox(height: 11),
        _Info(controller: controller, repo: repo),
        const Spacer(),
        GlassField(
          controller: repo.message,
          hint: dirty ? l.cardCommitHint : l.nothingToCommit,
          enabled: dirty && idle,
          icon: Icons.chat_bubble_outline_rounded,
          onSubmitted: (_) => _commit(context),
          suffix: GlassButton(
            onPressed: dirty && idle
                ? () {
                    toast(context,
                        l.cardAiWriting(providerLabel(l, controller.aiProvider), providerSpeed(l, controller.aiProvider)));
                    runWithFeedback(context, () => controller.writeMessage(repo));
                  }
                : null,
            busy: repo.writing,
            icon: Icons.auto_awesome_rounded,
            tone: GlassTone.rose,
            height: 30,
            radius: 8,
            tooltip: l.cardAiWriteTooltip,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: GlassButton(
              onPressed: dirty && idle ? () => _commit(context) : null,
              busy: repo.busy == 'Commit…',
              icon: Icons.check_rounded,
              label: dirty ? 'Commit ${compactCount(repo.files.length)}' : 'Commit',
              tone: GlassTone.green,
              height: 38,
              expand: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GlassButton(
              onPressed: repo.ahead > 0 && idle ? () => runWithFeedback(context, () => controller.push(repo)) : null,
              busy: repo.busy == 'Push…',
              icon: Icons.north_rounded,
              label: repo.ahead > 0 ? 'Push ${repo.ahead}' : 'Push',
              tone: GlassTone.blue,
              height: 38,
              expand: true,
            ),
          ),
        ]),
      ]),
    );
  }

  void _commit(BuildContext context) => runWithFeedback(context, () => controller.commit(repo));
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.repo, required this.onOpen});

  final WatcherController controller;
  final RepoState repo;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final branch = repo.status?.branch ?? '…';
    final root = controller.config.root;
    final where = repo.path == root ? repoFolderName(root) : repo.path.substring(root.length + 1);
    return Row(children: [
      RepoIcon(name: repo.name, iconPath: repo.iconPath),
      const SizedBox(width: 11),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(repo.name, style: Txt.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.call_split_rounded, size: 13, color: Palette.inkSoft),
            const SizedBox(width: 3),
            Text(
              repo.dirty ? '$branch*' : branch,
              style: Txt.body.copyWith(fontSize: 11.5, fontWeight: FontWeight.w400, color: repo.dirty ? Palette.orange : Palette.inkSoft),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text('· $where', style: Txt.muted.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ]),
      ),
      const SizedBox(width: 6),
      GlassButton(
        onPressed: onOpen,
        busy: repo.busy != null,
        icon: Icons.visibility_outlined,
        height: 30,
        radius: 9,
        tooltip: repo.busy ?? context.l10n.cardViewChanges,
      ),
      const SizedBox(width: 6),
      RepoMenu(controller: controller, repo: repo),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.repo);

  final RepoState repo;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (repo.status == null) {
      return Text(repo.error ?? l.cardReadingStatus, style: Txt.muted, maxLines: 4, overflow: TextOverflow.ellipsis);
    }
    if (!repo.dirty) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Line(icon: Icons.auto_awesome_rounded, color: Palette.green, text: l.cardCleanTree),
        const SizedBox(height: 7),
        _Line(icon: Icons.task_alt_rounded, color: Palette.inkSoft, text: l.nothingToCommit, muted: true),
      ]);
    }
    final counts = repo.status!.counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final added = repo.addedLines;
    final deleted = repo.deletedLines;
    final green = added + deleted == 0 ? 0 : (5 * added / (added + deleted)).round();
    return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final entry in counts.take(4))
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Icon(Palette.kindIcon(entry.key), size: 15, color: Palette.kind(entry.key)),
            const SizedBox(width: 7),
            Text('${entry.value}', style: Txt.strong.copyWith(fontSize: 12)),
            Text(' ${kindLabel(l, entry.key)}', style: Txt.body.copyWith(fontSize: 12)),
          ]),
        ),
      Row(children: [
        const Icon(Icons.bar_chart_rounded, size: 15, color: Palette.inkSoft),
        const SizedBox(width: 7),
        if (added > 0) ...[
          Text('+$added', style: Txt.strong.copyWith(fontSize: 12, color: Palette.addedText)),
          const SizedBox(width: 5),
        ],
        if (deleted > 0) ...[
          Text('−$deleted', style: Txt.strong.copyWith(fontSize: 12, color: Palette.deletedText)),
          const SizedBox(width: 5),
        ],
        const SizedBox(width: 1),
        for (var i = 0; i < 5; i++)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: i < green ? const Color(0xFF2FBF60) : const Color(0xFFEC3F5C),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ]),
    ]);
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.controller, required this.repo});

  final WatcherController controller;
  final RepoState repo;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = repo.status;
    final ci = repo.ci;
    final (IconData syncIcon, Color syncColor, String syncText, bool syncMuted) = switch (repo) {
      _ when repo.error != null => (Icons.error_outline_rounded, Palette.red, repo.error!, false),
      _ when repo.operation != RepoOperation.none =>
        (Icons.warning_amber_rounded, Palette.orange, l.cardOperationInProgress(operationLabel(repo.operation)), false),
      _ when repo.ahead > 0 => (Icons.north_rounded, Palette.blue, l.commitsAhead(repo.ahead), false),
      _ when repo.behind > 0 => (Icons.south_rounded, Palette.amber, l.commitsBehind(repo.behind), false),
      _ when status != null && status.upstream == null => (Icons.cloud_off_rounded, Palette.inkFaint, l.cardNoUpstream, true),
      _ => (Icons.compare_arrows_rounded, Palette.green, l.cardUpToDate(status?.upstream ?? 'remote'), true),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.commit_rounded, size: 15, color: Palette.inkSoft),
        const SizedBox(width: 8),
        Expanded(
          child: Text(status?.lastCommitSubject ?? l.cardNoCommits, style: Txt.body.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.schedule_rounded, size: 12, color: Palette.inkSoft),
        const SizedBox(width: 3),
        Text(relativeTime(l, status?.lastCommitAt), style: Txt.muted.copyWith(fontSize: 11.5)),
      ]),
      const SizedBox(height: 7),
      _Line(icon: syncIcon, color: syncColor, text: syncText, muted: syncMuted),
      const SizedBox(height: 7),
      _CiRow(controller: controller, repo: repo, ci: ci),
    ]);
  }
}

class _CiRow extends StatelessWidget {
  const _CiRow({required this.controller, required this.repo, required this.ci});

  final WatcherController controller;
  final RepoState repo;
  final CiStatus ci;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (ci.state) {
      CiState.none => (Icons.radio_button_unchecked_rounded, Palette.inkFaint),
      CiState.queued => (Icons.hourglass_top_rounded, Palette.amber),
      CiState.running => (Icons.autorenew_rounded, Palette.blue),
      CiState.success => (Icons.check_circle_rounded, Palette.green),
      CiState.failure => (Icons.cancel_rounded, Palette.red),
      CiState.cancelled => (Icons.do_not_disturb_on_outlined, Palette.inkSoft),
    };
    final l = context.l10n;
    final watched = controller.isCiWatched(repo);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 24,
        child: Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                if (ci.state != CiState.none) TextSpan(text: 'CI · ', style: Txt.body.copyWith(fontSize: 12)),
                TextSpan(text: ciLabel(l, ci), style: Txt.muted),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (ci.active) Text('${(ci.progress * 100).round()}%', style: Txt.strong.copyWith(fontSize: 12, color: color)),
          if (ci.state == CiState.failure && ci.runId != null) ...[
            const SizedBox(width: 6),
            GlassButton(
              onPressed: repo.busy == null ? () => startFixCi(context, controller, [repo]) : null,
              icon: Icons.auto_awesome_rounded,
              label: l.cardFixCi,
              tone: GlassTone.rose,
              height: 24,
              radius: 7,
              tooltip: l.cardFixCiTooltip,
            ),
          ],
          if (ci.state != CiState.none) ...[
            const SizedBox(width: 6),
            GlassButton(
              onPressed: () => controller.toggleCiWatch(repo),
              icon: watched ? Icons.visibility_rounded : Icons.visibility_off_outlined,
              tone: watched ? GlassTone.blue : GlassTone.neutral,
              height: 24,
              radius: 7,
              tooltip: watched ? l.cardCiWatching : l.cardWatchCi,
            ),
          ],
        ]),
      ),
      if (ci.active) ...[
        const SizedBox(height: 5),
        _ProgressBar(value: ci.state == CiState.queued ? null : ci.progress, color: color),
      ],
    ]);
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});

  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          child: value == null
              ? LinearProgressIndicator(color: color, backgroundColor: const Color(0x141F2547))
              : TweenAnimationBuilder<double>(
                  tween: Tween(end: value),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) =>
                      LinearProgressIndicator(value: v, color: color, backgroundColor: const Color(0x141F2547)),
                ),
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text, this.muted = false});

  final IconData icon;
  final Color color;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: muted ? Txt.muted : Txt.body.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]);
}
