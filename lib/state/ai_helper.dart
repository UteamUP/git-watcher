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
    summary = 'vinnur í ${targets.length} repo…';
    notifyListeners();

    var finished = 0;
    for (final repo in targets) {
      if (await _ship(repo)) finished++;
    }

    running = false;
    summary = 'Búið · $finished af ${targets.length} repo kláruð';
    notifyListeners();
  }

  Future<bool> _ship(RepoState repo) async {
    final service = watcher.service;
    repo.busy = 'AI helper…';
    watcher.notify();
    try {
      await watcher.refreshRepo(repo.path);
      var status = repo.status ?? (throw GitException(repo.error ?? 'Could not read the repository'));
      if (status.operation != RepoOperation.none) {
        throw GitException('A ${operationLabel(status.operation)} is in progress');
      }

      if (status.files.isNotEmpty) {
        var message = repo.message.text.trim();
        if (message.isEmpty) {
          await _step(repo, Icons.edit_note_rounded, 'Skrifa commit skilaboð', () async {
            message = await watcher.generateMessage(repo, subjectOnly: false);
          });
        }
        await _step(repo, Icons.check_rounded, 'Commit ${fileCount(status.files.length)}',
            () => service.commit(repo.path, status.files, message, operation: status.operation));
        repo.message.clear();
      }

      await _step(repo, Icons.cloud_download_rounded, 'Fetch', () => service.fetch(repo.path));
      status = await service.status(repo.path);
      if (status.behind > 0) {
        await _step(repo, Icons.south_rounded, 'Pull með rebase', () => service.pullRebase(repo.path));
        status = await service.status(repo.path);
      }
      if (status.ahead > 0 || (status.upstream == null && status.hasCommits)) {
        await _step(repo, Icons.north_rounded, 'Push á ${status.upstream ?? 'origin'}', () => service.push(repo.path));
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
    summary = repos.length == 1 ? 'lagar CI í ${repos.first.name}…' : 'lagar CI í ${repos.length} repo…';
    notifyListeners();

    var fixedCount = 0;
    var last = '';
    for (final repo in repos) {
      final (fixed, outcome) = await _fixCiOne(repo);
      if (fixed) fixedCount++;
      last = outcome;
    }
    running = false;
    summary = repos.length == 1 ? last : 'Búið · CI lagað og pushað í $fixedCount af ${repos.length} repo';
    notifyListeners();
  }

  Future<(bool, String)> _fixCiOne(RepoState repo) async {
    final runId = repo.ci.runId!;
    repo.busy = 'Lagar CI…';
    watcher.notify();
    var fixed = false;
    var outcome = 'Tókst ekki að laga CI';
    final headBefore = '${repo.status?.lastCommitAt}|${repo.status?.lastCommitSubject}';
    try {
      var log = '';
      await _step(repo, Icons.receipt_long_rounded, 'Sæki villuna úr CI keyrslunni', () async {
        log = await watcher.ci.failedLog(repo.path, runId);
      });
      final (step, result) = await _runAgent(repo, '''
The latest GitHub Actions run for this branch failed${repo.ci.failedJob == null ? '' : ' in the job "${repo.ci.failedJob}"'}.
Output of the failed steps (newest lines):

$log

Find the root cause in this repository and fix it with the smallest sensible change.
Commit with a Conventional Commit message, rebase on the upstream (git pull --rebase --autostash) and push.
Never force-push, never use --no-verify, never amend existing commits, and never skip or disable tests to make CI pass.
If the failure is not caused by code in this repository (a missing secret, an outage, a flaky runner), change nothing and explain the cause.
End with one short sentence that says what you did.''');
      // Judge by what happened to the repository, not by what the agent says.
      await watcher.refreshRepo(repo.path);
      final changed = '${repo.status?.lastCommitAt}|${repo.status?.lastCommitSubject}' != headBefore;
      if (result != null && !result.failed) {
        fixed = changed && repo.ahead == 0 && !repo.dirty;
        if (!fixed) {
          step
            ..state = HelperStepState.warning
            ..text = changed ? 'Breytt en ekki pushað: ${result.text}' : 'Engu breytt: ${result.text}';
          outcome = changed ? 'Lagfæring bíður push' : 'Engu breytt · sjá skýringu agentsins';
        }
      }
    } on Object catch (error) {
      _add(HelperStep(repo.name, Icons.error_outline_rounded, firstLine(error), HelperStepState.failed));
    } finally {
      repo.busy = null;
      await watcher.refreshRepo(repo.path);
    }
    if (fixed) watcher.expectCi(repo);
    return (fixed, fixed ? 'Lagað og pushað · fylgist með nýrri CI keyrslu' : outcome);
  }

  Future<bool> _agent(RepoState repo, Object error) async {
    _add(HelperStep(repo.name, Icons.warning_amber_rounded, 'Vandamál: ${firstLine(error)}. AI agent tekur við', HelperStepState.warning));
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
        ..text = 'Ekki lokið: ${result.text}';
      notifyListeners();
    }
    return done;
  }

  /// Streams the agent's steps into one row and returns that row with the final event (null if it never ran).
  Future<(HelperStep, AgentEvent?)> _runAgent(RepoState repo, String task) async {
    final step = _add(HelperStep(repo.name, Icons.smart_toy_rounded, '${agentLabel(watcher.agent)} vinnur…'));
    try {
      await for (final event in watcher.ai.runAgent(agent: watcher.agent, repo: repo.path, task: task)) {
        step.text = event.done && event.text.isEmpty ? 'AI agent kláraði' : event.text;
        if (event.done) step.state = event.failed ? HelperStepState.failed : HelperStepState.done;
        notifyListeners();
        if (event.done) return (step, event);
      }
    } on Object catch (agentError) {
      step
        ..text = 'AI agent gat ekki byrjað: ${firstLine(agentError)}'
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
