import 'package:flutter/material.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../format.dart';
import 'watcher_controller.dart';

enum HelperStepState { running, done, failed, warning }

class HelperStep {
  HelperStep(this.repo, this.icon, this.text, [this.state = HelperStepState.running]);

  final String repo;
  final IconData icon;
  String text;
  HelperStepState state;
}

/// Ships repositories end to end: AI message, commit, rebase, push.
/// When a step fails, a Claude Code agent takes over that repo and finishes the job.
class AiHelper extends ChangeNotifier {
  AiHelper(this.watcher);

  final WatcherController watcher;
  final steps = <HelperStep>[];
  bool running = false;
  bool visible = false;
  String summary = '';

  void hide() {
    visible = false;
    notifyListeners();
  }

  Future<void> run(List<RepoState> targets) async {
    if (running || targets.isEmpty) return;
    running = true;
    visible = true;
    steps.clear();
    summary = watcher.l10n.topHelperWorkingOn(targets.length);
    notifyListeners();

    var finished = 0;
    for (final repo in targets) {
      if (await _ship(repo)) finished++;
    }

    running = false;
    summary = watcher.l10n.topHelperDone(finished, targets.length);
    notifyListeners();
  }

  /// Ships one repository: AI message, commit, rebase and push.
  ///
  /// The menu bar panel calls this, so it answers whether the repository ended up clean and pushed.
  Future<bool> ship(RepoState repo) async {
    if (running) return false;
    running = true;
    visible = true;
    steps.clear();
    summary = watcher.l10n.topHelperWorkingOn(1);
    notifyListeners();
    var ok = false;
    try {
      ok = await _ship(repo);
    } finally {
      running = false;
      summary = ok ? watcher.l10n.topHelperDone(1, 1) : '';
      notifyListeners();
    }
    return ok;
  }

  Future<bool> _ship(RepoState repo) async {
    final service = watcher.service;
    final l = watcher.l10n;
    repo.busy = 'AI helper…';
    watcher.notify();
    try {
      await watcher.refreshRepo(repo.path);
      var status = repo.status ?? (throw GitException(repo.error ?? 'Could not read the repository'));
      if (status.operation != RepoOperation.none) {
        throw GitException(l.cardOperationInProgress(operationLabel(status.operation)));
      }

      if (status.files.isNotEmpty) {
        var message = repo.message.text.trim();
        if (message.isEmpty) {
          await _step(repo, Icons.edit_note_rounded, l.topHelperWritingMessage, () async {
            message = await watcher.generateMessage(repo, subjectOnly: false);
          });
        }
        await _step(repo, Icons.check_rounded, l.topHelperCommitFiles(status.files.length),
            () => service.commit(repo.path, status.files, message, operation: status.operation));
        repo.message.clear();
      }

      await _step(repo, Icons.cloud_download_rounded, 'Fetch', () => service.fetch(repo.path));
      status = await service.status(repo.path);
      if (status.behind > 0) {
        await _step(repo, Icons.south_rounded, l.pullWithRebase, () => service.pullRebase(repo.path));
        status = await service.status(repo.path);
      }
      if (status.ahead > 0 || (status.upstream == null && status.hasCommits)) {
        await _step(repo, Icons.north_rounded, l.topHelperPushTo(status.upstream ?? 'origin'), () => service.push(repo.path));
      }
      return true;
    } on Object catch (error) {
      return _agent(repo, error);
    } finally {
      repo.busy = null;
      await watcher.refreshRepo(repo.path);
    }
  }

  Future<void> _step(RepoState repo, IconData icon, String text, Future<void> Function() work) async {
    final step = _add(HelperStep(repo.name, icon, text));
    try {
      await work();
      step.state = HelperStepState.done;
    } on Object {
      step.state = HelperStepState.failed;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Fixes the failed CI of each repo in turn: read the log, let the agent fix, commit and push, watch the new run.
  Future<void> fixCi(List<RepoState> targets) async {
    final repos = targets.where((r) => r.ci.state == CiState.failure && r.ci.runId != null).toList();
    if (running || repos.isEmpty) return;
    running = true;
    visible = true;
    steps.clear();
    final l = watcher.l10n;
    summary = repos.length == 1 ? l.topHelperFixingCiIn(repos.first.name) : l.topHelperFixingCiRepos(repos.length);
    notifyListeners();

    var fixedCount = 0;
    var last = '';
    for (final repo in repos) {
      final (fixed, outcome) = await _fixCiOne(repo);
      if (fixed) fixedCount++;
      last = outcome;
    }
    running = false;
    summary = repos.length == 1 ? last : watcher.l10n.topHelperCiDone(fixedCount, repos.length);
    notifyListeners();
  }

  Future<(bool, String)> _fixCiOne(RepoState repo) async {
    final l = watcher.l10n;
    final runs = repo.ci.failedRuns.isEmpty ? [repo.ci.runId!] : repo.ci.failedRuns;
    repo.busy = l.topBusyFixingCi;
    watcher.notify();
    var fixed = false;
    var outcome = l.topCiFixFailed;
    final headBefore = '${repo.status?.lastCommitAt}|${repo.status?.lastCommitSubject}';
    // Work that was uncommitted before the fix is the user's: it may stay, and it does not count against the fix.
    final dirtyBefore = {...?repo.status?.files.map((f) => f.path)};
    try {
      var log = '';
      await _step(repo, Icons.receipt_long_rounded, l.topHelperFetchingCiLog, () async {
        log = await watcher.ci.failedLog(repo.path, runs);
      });
      final (step, result) = await _runAgent(repo, '''
GitHub Actions failed for the newest commit on this branch${repo.ci.failedJob == null ? '' : ', first in the job "${repo.ci.failedJob}"'}.
Output of the failed steps of every failed workflow run (newest lines):

$log

Several jobs or workflows may have failed. Find the root cause of each one and fix every failure that code in
this repository causes, with the smallest sensible change.
Files that were already uncommitted belong to the user: leave them as they are and commit only the files you
changed (git add <path>, never git add -A or git commit -a).
Commit with a Conventional Commit message whose body uses real line breaks (git commit -F - with a here-document,
never a literal \\n), rebase on the upstream (git pull --rebase --autostash) and push.
Never force-push, never use --no-verify, never amend existing commits, and never skip or disable tests to make CI pass.
If a failure needs something outside this repository (a secret, a cloud permission, a repository setting, an
outage or a flaky runner), do not work around it: name exactly what has to change and where.
End with one short sentence that says what you fixed and what, if anything, the user still has to change.''');
      // Judge by what happened to the repository, not by what the agent says.
      await watcher.refreshRepo(repo.path);
      final changed = '${repo.status?.lastCommitAt}|${repo.status?.lastCommitSubject}' != headBefore;
      if (result != null && !result.failed) {
        final leftOver = (repo.status?.files ?? const <FileChange>[]).where((f) => !dirtyBefore.contains(f.path));
        fixed = changed && repo.ahead == 0 && leftOver.isEmpty;
        if (!fixed) {
          final said = agentEventText(l, result);
          step
            ..state = HelperStepState.warning
            ..text = changed ? l.topAgentChangedNotPushed(said) : l.topAgentNoChange(said);
          outcome = changed ? l.topFixAwaitingPush : l.topNoChangeSeeAgent;
        }
      }
    } on Object catch (error) {
      _add(HelperStep(repo.name, Icons.error_outline_rounded, firstLine(l, error), HelperStepState.failed));
    } finally {
      repo.busy = null;
      await watcher.refreshRepo(repo.path);
    }
    if (fixed) watcher.expectCi(repo);
    return (fixed, fixed ? l.topFixedWatchingCi : outcome);
  }

  Future<bool> _agent(RepoState repo, Object error) async {
    final l = watcher.l10n;
    _add(HelperStep(repo.name, Icons.warning_amber_rounded, l.topHelperProblem(firstLine(l, error)), HelperStepState.warning));
    final (step, result) = await _runAgent(repo, '''
GIT Watcher tried to commit and push this repository and stopped with this error:

$error

Finish the job in this repository: commit every intended uncommitted change with a Conventional Commit message,
rebase the branch on its upstream (git pull --rebase --autostash), resolve conflicts carefully, then push.
Never force-push, never use --no-verify, never amend existing commits.
If a hook or test fails for a reason you cannot fix safely, stop and explain why.
End with one short sentence that says what you did.''');
    if (result == null || result.failed) return false;
    // Done means clean and pushed, whatever the agent reports.
    await watcher.refreshRepo(repo.path);
    final done = !repo.dirty && repo.ahead == 0 && repo.operation == RepoOperation.none;
    if (!done) {
      step
        ..state = HelperStepState.warning
        ..text = l.topAgentNotFinished(agentEventText(l, result));
      notifyListeners();
    }
    return done;
  }

  /// Streams the agent's steps into one row and returns that row with the final event (null if it never ran).
  Future<(HelperStep, AgentEvent?)> _runAgent(RepoState repo, String task) async {
    final l = watcher.l10n;
    final step = _add(HelperStep(repo.name, Icons.smart_toy_rounded, l.topAgentWorking(agentLabel(l, watcher.agent))));
    try {
      await for (final event in watcher.ai.runAgent(agent: watcher.agent, repo: repo.path, task: task)) {
        final text = agentEventText(l, event);
        step.text = event.done && text.isEmpty ? l.topAgentFinished : text;
        if (event.done) step.state = event.failed ? HelperStepState.failed : HelperStepState.done;
        notifyListeners();
        if (event.done) return (step, event);
      }
    } on Object catch (agentError) {
      step
        ..text = l.topAgentCouldNotStart(firstLine(l, agentError))
        ..state = HelperStepState.failed;
      notifyListeners();
    }
    return (step, null);
  }

  HelperStep _add(HelperStep step) {
    steps.add(step);
    notifyListeners();
    return step;
  }
}
