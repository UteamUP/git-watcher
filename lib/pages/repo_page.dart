import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../state/repo_controller.dart';
import '../state/watcher_controller.dart';
import '../theme.dart';
import '../ui/feedback.dart';
import '../ui/glass.dart';
import '../ui/system.dart';
import '../widgets/diff_view.dart';
import '../widgets/file_row.dart';
import '../widgets/menus.dart';
import '../widgets/repo_icon.dart';

void openRepo(BuildContext context, WatcherController controller, RepoState repo) =>
    openRepoWith(Navigator.of(context), controller, repo);

/// Opens the repository page on a navigator the caller already has, for the menu bar panel.
void openRepoWith(NavigatorState navigator, WatcherController controller, RepoState repo) {
  navigator.push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => RepoPage(controller: controller, repo: repo),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: .985, end: 1.0).animate(curved), child: child),
      );
    },
  ));
}

class RepoPage extends StatefulWidget {
  const RepoPage({super.key, required this.controller, required this.repo});

  final WatcherController controller;
  final RepoState repo;

  @override
  State<RepoPage> createState() => _RepoPageState();
}

class _RepoPageState extends State<RepoPage> {
  late final RepoController page = RepoController(widget.controller, widget.repo);

  @override
  void dispose() {
    page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true): () => Navigator.maybePop(context),
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () => widget.controller.refreshRepo(widget.repo.path),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: ListenableBuilder(
              listenable: Listenable.merge([widget.controller, page]),
              builder: (context, _) => Column(children: [
                _Header(controller: widget.controller, repo: widget.repo),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        SizedBox(
                          width: math.min(420, constraints.maxWidth * .38),
                          child: GlassPanel(radius: 22, child: _LeftPanel(page: page)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: GlassPanel(radius: 22, tint: const Color(0xA8FFFFFF), child: _DiffPane(page: page))),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.repo});

  final WatcherController controller;
  final RepoState repo;

  @override
  Widget build(BuildContext context) {
    final idle = repo.busy == null;
    final operation = repo.operation;
    return WindowDragArea(
      child: GlassPanel(
        radius: 0,
        rim: false,
        shadow: false,
        tint: const Color(0x57FFFFFF),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.only(left: 84, right: 16),
            child: Row(children: [
              GlassButton(onPressed: () => Navigator.maybePop(context), icon: Icons.chevron_left_rounded, tooltip: context.l10n.repoBack),
              const SizedBox(width: 12),
              RepoIcon(name: repo.name, iconPath: repo.iconPath, size: 34),
              const SizedBox(width: 10),
              Flexible(child: Text(repo.name, style: Txt.title.copyWith(fontSize: 16.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 12),
              GlassChip(
                icon: Icons.call_split_rounded,
                label: repo.dirty ? '${repo.status?.branch ?? ''}*' : repo.status?.branch ?? '',
                color: repo.dirty ? Palette.orange : Palette.inkSoft,
              ),
              if (repo.ahead > 0) ...[
                const SizedBox(width: 6),
                GlassChip(icon: Icons.north_rounded, label: '${repo.ahead}', color: Palette.blue),
              ],
              if (repo.behind > 0) ...[
                const SizedBox(width: 6),
                GlassChip(icon: Icons.south_rounded, label: '${repo.behind}', color: Palette.amber),
              ],
              if (operation != RepoOperation.none) ...[
                const SizedBox(width: 10),
                GlassChip(icon: Icons.warning_amber_rounded, label: context.l10n.repoOperationInProgress(operationLabel(operation)), color: Palette.orange),
                const SizedBox(width: 6),
                GlassButton(
                  onPressed: idle ? () => runWithFeedback(context, () => controller.continueOperation(repo)) : null,
                  icon: Icons.play_arrow_rounded,
                  label: context.l10n.repoContinue,
                  tone: GlassTone.green,
                ),
                const SizedBox(width: 6),
                GlassButton(
                  onPressed: idle ? () => runWithFeedback(context, () => controller.abortOperation(repo)) : null,
                  icon: Icons.close_rounded,
                  label: context.l10n.repoAbort,
                ),
              ],
              const Spacer(),
              if (!idle) ...[
                const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: Palette.blue)),
                const SizedBox(width: 8),
                Text(repo.busy!, style: Txt.muted),
                const SizedBox(width: 12),
              ],
              GlassButton(
                onPressed: idle ? () => runWithFeedback(context, () => controller.fetch(repo), success: context.l10n.fetchDone) : null,
                icon: Icons.cloud_download_outlined,
                label: 'Fetch',
                tone: GlassTone.violet,
              ),
              const SizedBox(width: 8),
              GlassButton(
                onPressed: idle ? () => runWithFeedback(context, () => controller.pullRebase(repo)) : null,
                icon: Icons.south_rounded,
                label: 'Pull',
                tone: GlassTone.blue,
                tooltip: 'git pull --rebase --autostash',
              ),
              const SizedBox(width: 8),
              GlassButton(
                onPressed: idle && repo.ahead > 0 ? () => runWithFeedback(context, () => controller.push(repo)) : null,
                icon: Icons.north_rounded,
                label: repo.ahead > 0 ? 'Push ${repo.ahead}' : 'Push',
                tone: GlassTone.blue,
              ),
              const SizedBox(width: 8),
              RepoMenu(controller: controller, repo: repo, size: 34),
            ]),
          ),
        ),
      ),
    );
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.page});

  final RepoController page;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _Segmented(
            selected: page.tab,
            onChanged: page.setTab,
            items: [
              (Icons.difference_outlined, context.l10n.repoTabChanges(page.files.length)),
              (Icons.history_rounded, context.l10n.repoTabHistory),
            ],
          ),
        ),
        Expanded(child: page.tab == 0 ? _Changes(page: page) : _History(page: page)),
        if (page.tab == 0 && page.repo.dirty) _CommitBox(page: page),
      ]);
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.selected, required this.onChanged, required this.items});

  final int selected;
  final ValueChanged<int> onChanged;
  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: const Color(0x121F2547), borderRadius: BorderRadius.circular(11)),
        child: Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: i == selected ? const Color(0xD9FFFFFF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: i == selected ? const [BoxShadow(color: Color(0x1F3C1E50), blurRadius: 6, offset: Offset(0, 2))] : null,
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(items[i].$1, size: 15, color: i == selected ? Palette.blue : Palette.inkSoft),
                      const SizedBox(width: 6),
                      Text(items[i].$2, style: (i == selected ? Txt.strong : Txt.body).copyWith(fontSize: 12.5)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );
}

class _Changes extends StatelessWidget {
  const _Changes({required this.page});

  final RepoController page;

  @override
  Widget build(BuildContext context) {
    final repo = page.repo;
    if (!repo.dirty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.task_alt_rounded, size: 46, color: Palette.green),
          const SizedBox(height: 10),
          Text(context.l10n.nothingToCommit, style: Txt.title),
          const SizedBox(height: 4),
          Text(
            repo.ahead > 0 ? context.l10n.repoCleanWithAhead(context.l10n.commitsAhead(repo.ahead)) : context.l10n.repoClean,
            style: Txt.muted,
          ),
          const SizedBox(height: 14),
          GlassButton(onPressed: () => page.setTab(1), icon: Icons.history_rounded, label: context.l10n.repoViewHistory),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          SizedBox(
            width: 28,
            child: Checkbox(
              tristate: true,
              value: page.allIncluded,
              onChanged: (_) => page.toggleAll(),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          Text(context.l10n.repoSelectedCount(page.included.length, page.files.length), style: Txt.muted),
          const Spacer(),
          Text('+${repo.addedLines}', style: Txt.strong.copyWith(fontSize: 11.5, color: Palette.addedText)),
          const SizedBox(width: 5),
          Text('−${repo.deletedLines}', style: Txt.strong.copyWith(fontSize: 11.5, color: Palette.deletedText)),
        ]),
      ),
      const SizedBox(height: 4),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          itemCount: page.files.length,
          itemBuilder: (context, i) {
            final file = page.files[i];
            return FileRow(
              file: file,
              stat: repo.lines[file.path],
              selected: page.selectedCommit == null && page.selected?.path == file.path,
              checked: !page.excluded.contains(file.path),
              onChecked: () => page.toggle(file),
              onTap: () => page.selectFile(file),
              onContextMenu: (position) => _fileMenu(context, position, file),
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _fileMenu(BuildContext context, Offset position, FileChange file) async {
    final repo = page.repo;
    final l = context.l10n;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        _popupItem('discard', Icons.undo_rounded, l.repoDiscardChanges),
        _popupItem('finder', Icons.folder_open_rounded, l.repoShowInFinder),
        _popupItem('code', Icons.code_rounded, l.openInVsCode),
      ],
    );
    final full = '${repo.path}/${file.path}';
    switch (choice) {
      case 'finder':
        await revealInFinder(full);
      case 'code':
        await openInVsCode(full);
      case 'discard':
        if (!context.mounted) return;
        final newFile = file.kind == ChangeKind.untracked || file.kind == ChangeKind.added;
        final go = await confirm(
          context,
          title: l.repoDiscardChangesTitle,
          icon: Icons.undo_rounded,
          tone: GlassTone.rose,
          action: l.repoDiscard,
          body: Text(
            newFile ? l.repoDiscardNewFileBody(file.path) : l.repoDiscardChangesBody(file.path),
            style: Txt.body.copyWith(fontSize: 13, height: 1.5),
          ),
        );
        if (go && context.mounted) {
          await runWithFeedback(context, () => page.watcher.discard(repo, file), success: l.repoChangesDiscarded(file.fileName));
        }
    }
  }

  static PopupMenuItem<String> _popupItem(String value, IconData icon, String label) => PopupMenuItem(
        value: value,
        height: 36,
        child: Row(children: [Icon(icon, size: 17, color: Palette.inkSoft), const SizedBox(width: 10), Text(label)]),
      );
}

class _CommitBox extends StatelessWidget {
  const _CommitBox({required this.page});

  final RepoController page;

  @override
  Widget build(BuildContext context) {
    final repo = page.repo;
    final idle = repo.busy == null;
    final canCommit = idle && page.included.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x141F2547)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GlassField(controller: page.message, hint: context.l10n.repoCommitMessageHint, minLines: 3, maxLines: 6, enabled: idle),
        const SizedBox(height: 8),
        Row(children: [
          GlassButton(
            onPressed: canCommit && !repo.writing ? () => runWithFeedback(context, page.writeMessage) : null,
            busy: repo.writing,
            icon: Icons.auto_awesome_rounded,
            label: context.l10n.repoWriteWithAi,
            tone: GlassTone.rose,
            height: 32,
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: GlassButton(
              onPressed: canCommit ? () => runWithFeedback(context, page.commit) : null,
              icon: Icons.check_rounded,
              label: 'Commit ${page.included.length}',
              tone: GlassTone.green,
              height: 38,
              expand: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GlassButton(
              onPressed: canCommit ? () => runWithFeedback(context, () => page.commit(push: true)) : null,
              icon: Icons.north_rounded,
              label: context.l10n.repoCommitAndPush,
              tone: GlassTone.blue,
              height: 38,
              expand: true,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.page});

  final RepoController page;

  @override
  Widget build(BuildContext context) {
    if (page.commits.isEmpty) {
      return Center(
        child: page.historyLoading
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.blue))
            : Text(context.l10n.repoNoCommitsYet, style: Txt.muted),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      itemCount: page.commits.length,
      itemBuilder: (context, i) => _CommitTile(page: page, commit: page.commits[i], first: i == 0, last: i == page.commits.length - 1),
    );
  }
}

class _CommitTile extends StatelessWidget {
  const _CommitTile({required this.page, required this.commit, required this.first, required this.last});

  final RepoController page;
  final Commit commit;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final open = page.expanded == commit.hash;
    final files = page.commitFiles[commit.hash];
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 26,
          child: CustomPaint(painter: _TimelinePainter(top: !first, bottom: !last || open, pushed: commit.pushed)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => page.toggleCommit(commit.hash),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(color: open ? const Color(0x1F1A6BB5) : null, borderRadius: BorderRadius.circular(9)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(commit.subject, style: Txt.body.copyWith(fontWeight: FontWeight.w400), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text(commit.shortHash, style: Txt.mono.copyWith(fontSize: 11, color: Palette.inkSoft)),
                      Expanded(
                        child: Text(' · ${commit.author} · ${relativeTime(context.l10n, commit.date)}',
                            style: Txt.muted.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (!commit.pushed) GlassChip(icon: Icons.north_rounded, label: context.l10n.repoNotPushed, color: Palette.blue),
                    ]),
                  ]),
                ),
              ),
            ),
            if (open)
              files == null
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(child: SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 1.8))),
                    )
                  : Column(children: [
                      for (final file in files)
                        FileRow(
                          file: file,
                          selected: page.selectedCommit == commit.hash && page.selected?.path == file.path,
                          onTap: () => page.selectCommitFile(commit.hash, file),
                        ),
                    ]),
          ]),
        ),
      ]),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({required this.top, required this.bottom, required this.pushed});

  final bool top;
  final bool bottom;
  final bool pushed;

  @override
  void paint(Canvas canvas, Size size) {
    const dotY = 16.0;
    final x = size.width / 2;
    final line = Paint()
      ..color = const Color(0x381F2547)
      ..strokeWidth = 1.4;
    if (top) canvas.drawLine(Offset(x, 0), Offset(x, dotY), line);
    if (bottom) canvas.drawLine(Offset(x, dotY), Offset(x, size.height), line);
    if (pushed) {
      canvas
        ..drawCircle(Offset(x, dotY), 4.5, Paint()..color = const Color(0xFFF7F7FB))
        ..drawCircle(
          Offset(x, dotY),
          4.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0x8C4B5274),
        );
    } else {
      canvas.drawCircle(Offset(x, dotY), 5, Paint()..color = Palette.blue);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => old.top != top || old.bottom != bottom || old.pushed != pushed;
}

class _DiffPane extends StatelessWidget {
  const _DiffPane({required this.page});

  final RepoController page;

  @override
  Widget build(BuildContext context) {
    final file = page.selected;
    if (file == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.difference_outlined, size: 54, color: Palette.inkFaint),
          const SizedBox(height: 12),
          Text(context.l10n.repoSelectFile, style: Txt.title),
          const SizedBox(height: 4),
          Text(context.l10n.repoSelectFileHint, style: Txt.muted),
        ]),
      );
    }
    final diff = page.diff;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x141F2547)))),
        child: Row(children: [
          KindBadge(file.kind),
          const SizedBox(width: 10),
          Text(file.fileName, style: Txt.strong.copyWith(fontSize: 13.5)),
          const SizedBox(width: 8),
          Expanded(child: Text(file.directory, style: Txt.muted, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (page.selectedCommit != null) ...[
            GlassChip(icon: Icons.commit_rounded, label: page.selectedCommit!.substring(0, 7), color: Palette.violet),
            const SizedBox(width: 10),
          ],
          if (diff != null && diff.notice == DiffNotice.none) ...[
            Text('+${diff.additions}', style: Txt.strong.copyWith(color: Palette.addedText)),
            const SizedBox(width: 6),
            Text('−${diff.deletions}', style: Txt.strong.copyWith(color: Palette.deletedText)),
            const SizedBox(width: 12),
          ],
          GlassButton(
            onPressed: () => openInVsCode('${page.repo.path}/${file.path}'),
            icon: Icons.code_rounded,
            height: 30,
            radius: 9,
            tooltip: context.l10n.openInVsCode,
          ),
        ]),
      ),
      Expanded(
        child: page.diffLoading && diff == null
            ? const Center(child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.blue)))
            : page.diffError != null
                ? Center(child: Text(page.diffError!, style: Txt.muted.copyWith(color: Palette.red)))
                : diff == null
                    ? const SizedBox.shrink()
                    : DiffView(diff: diff),
      ),
    ]);
  }
}
