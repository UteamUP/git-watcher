import 'package:git_watcher_core/git_watcher_core.dart';

import '../format.dart';
import '../state/watcher_controller.dart';
import 'snapshot.dart';

/// What the menu bar shows: the repositories that have something waiting.
///
/// Only the first few changed files of each repository travel with the snapshot, so the panel
/// stays small no matter how big the work is.
MenuBarSnapshot buildMenuBarSnapshot(
  WatcherController controller, {
  String? notice,
  bool noticeError = false,
}) {
  final l = controller.l10n;
  final repos = controller.sorted.where((repo) => repo.needsAttention).toList();
  return MenuBarSnapshot(
    dirty: controller.dirtyCount,
    ahead: controller.aheadCount,
    ciRunning: controller.ciRunning,
    ciFailed: controller.ciFailed,
    repos: [
      for (final repo in repos)
        MenuBarRepo(
          path: repo.path,
          name: repo.name,
          iconPath: repo.iconPath,
          branch: repo.status?.branch ?? '',
          files: [
            for (final file in repo.files.take(2))
              MenuBarFile(path: file.path, name: file.fileName, kind: file.kind.name),
          ],
          fileCount: repo.files.length,
          added: repo.addedLines,
          deleted: repo.deletedLines,
          ahead: repo.ahead,
          behind: repo.behind,
          ciState: repo.ci.state.name,
          ciProgress: repo.ci.progress,
          ciText: repo.ci.state == CiState.none ? null : ciLabel(l, repo.ci),
          busy: repo.busy,
          lastCommit: repo.status?.lastCommitSubject,
        ),
    ],
    notice: notice,
    noticeError: noticeError,
  );
}
