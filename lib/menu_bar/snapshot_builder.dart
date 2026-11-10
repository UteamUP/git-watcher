import 'package:git_watcher_core/git_watcher_core.dart';

import '../format.dart';
import '../state/watcher_controller.dart';
import 'snapshot.dart';

/// What the menu bar shows: the repositories that have something waiting.
///
/// Only the work that is not committed or not pushed, and only the pipelines that are at work
/// or broken. What is already fine needs no attention here.
MenuBarSnapshot buildMenuBarSnapshot(
  WatcherController controller, {
  String? notice,
  bool noticeError = false,
}) {
  final l = controller.l10n;
  final repos = controller.sorted.where((repo) => repo.dirty || repo.ahead > 0).toList();
  return MenuBarSnapshot(
    dirty: controller.dirtyCount,
    ahead: controller.aheadCount,
    ciRunning: controller.ciRunning,
    ciFailed: controller.ciFailed,
    repos: [      for (final repo in repos)
        MenuBarRepo(
          path: repo.path,
          name: repo.name,
          iconPath: repo.iconPath,
          branch: repo.status?.branch ?? '',
          fileCount: repo.files.length,
          added: repo.addedLines,
          deleted: repo.deletedLines,
          ahead: repo.ahead,
          behind: repo.behind,
          ciState: repo.ci.state.name,
          ciProgress: repo.ci.progress,
          ciText: repo.ci.active || repo.ci.state == CiState.failure ? ciLabel(l, repo.ci) : null,
          busy: repo.busy,
        ),
    ],
    busy: controller.helper.running,
    notice: notice,
    noticeError: noticeError,
  );
}
