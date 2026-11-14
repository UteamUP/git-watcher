import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../ui/system.dart';
import 'ai_helper.dart';

class RepoState {
  RepoState(this.path, this.iconPath);

  final String path;
  String? iconPath;
  RepoStatus? status;
  Map<String, LineStat> lines = const {};
  CiStatus ci = CiStatus.none;
  String? error;
  String? busy;
  bool committing = false;

  String get name => repoDisplayName(path);
  String get folderName => repoFolderName(path);
  String get diskPath => formatDiskPath(path);
  String? get remoteUrl => status?.remoteUrl;
  List<FileChange> get files => status?.files ?? const [];
  bool get dirty => files.isNotEmpty;
  int get ahead => status?.ahead ?? 0;
  int get behind => status?.behind ?? 0;
  RepoOperation get operation => status?.operation ?? RepoOperation.none;
  int get addedLines => lines.values.fold(0, (sum, s) => sum + (s.added ?? 0));
  int get deletedLines => lines.values.fold(0, (sum, s) => sum + (s.deleted ?? 0));

  bool get needsAttention =>
      error != null ||
      dirty ||
      ahead > 0 ||
      behind > 0 ||
      operation != RepoOperation.none ||
      ci.state == CiState.failure ||
      ci.active;

  /// Something the AI helper can finish: changes to commit or commits to move.
  bool get shippable => dirty || ahead > 0 || behind > 0;
}

class WatcherController extends ChangeNotifier {
  WatcherController({required ProcessEnv env, required this.config, required this.locale})
      : home = env.home,
        service = GitWatcherService(Git(env)),
        ci = CiService(env),
        ai = AiService(env);

  final WatcherConfig config;

  /// The app's language; [setLanguage] changes it and remembers the choice.
  final ValueNotifier<Locale> locale;
  final String home;
  final GitWatcherService service;
  final CiService ci;
  final AiService ai;
  late final AiHelper helper = AiHelper(this);

  List<RepoState> _all = [];
  bool scanning = true;
  bool refreshing = false;
  bool fetching = false;
  bool committingAll = false;
  bool claudeReady = false;
  bool codexReady = false;

  final _inFlight = <String>{};
  final _again = <String>{};
  final _debounce = <String, Timer>{};
  final _fastCiUntil = <String, DateTime>{};
  final _lastAutoCommitAt = <String, DateTime>{};
  final _lastAutoPushAt = <String, DateTime>{};
  final _lastSkillCheckAt = <String, DateTime>{};
  final _autoBusy = <String>{};
  final _timers = <Timer>[];
  late final DateTime _startedAt = DateTime.now();

  /// Wall-clock tick once per second so countdown pills on cards update smoothly without rebuilding the whole app.
  late final ValueNotifier<DateTime> clock = ValueNotifier<DateTime>(_startedAt);
  var _automationTicking = false;
  StreamSubscription<FileSystemEvent>? _watch;
  var _disposed = false;

  /// Every repo that is not hidden. Hidden repos are skipped everywhere, bulk actions included.
  List<RepoState> get repos => _all.where((r) => !config.hidden.contains(r.path)).toList();

  List<RepoState> get hiddenRepos => _all.where((r) => config.hidden.contains(r.path)).toList();

  /// Repos that need something come first, the rest by name, so cards only move when their state does.
  List<RepoState> get sorted => repos..sort((a, b) {
      if (a.needsAttention != b.needsAttention) return a.needsAttention ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  int get dirtyCount => repos.where((r) => r.dirty).length;
  int get aheadCount => repos.where((r) => r.ahead > 0).length;
  int get ciRunning => repos.where((r) => r.ci.active).length;
  int get ciFailed => repos.where((r) => r.ci.state == CiState.failure).length;

  /// The chosen provider, or one that is signed in when nothing has been chosen yet.
  AiProvider get aiProvider => config.aiProvider ?? (claudeReady || !codexReady ? AiProvider.claudeCode : AiProvider.codex);

  AgentProvider get agent =>
      config.agent ?? (claudeReady ? AgentProvider.claudeCode : (codexReady ? AgentProvider.codex : AgentProvider.off));

  RepoState? byPath(String path) {
    for (final repo in _all) {
      if (repo.path == path) return repo;
    }
    return null;
  }

  Future<void> start() async {
    unawaited(checkAi());
    await _load();
    await _seedSkillBaselines();
    _timers.addAll([
      Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_disposed) clock.value = DateTime.now();
      }),
      Timer.periodic(const Duration(minutes: 2), (_) => refreshAll()),
      Timer.periodic(const Duration(minutes: 2), (_) => refreshCiAll()),
      Timer.periodic(const Duration(seconds: 15), (_) => _pollActiveCi()),
      Timer.periodic(const Duration(minutes: 15), (_) => fetchAll()),
      Timer.periodic(const Duration(seconds: 3), (_) => _tickAutomation()),
    ]);
  }

  Future<void> checkAi() async {
    final signedIn = await Future.wait([ai.claudeLoggedIn(), ai.codexLoggedIn()]);
    claudeReady = signedIn[0];
    codexReady = signedIn[1];
    _notify();
  }

  void setAiProvider(AiProvider provider) {
    config
      ..aiProvider = provider
      ..save();
    _notify();
  }

  AppLocalizations get l10n => lookupAppLocalizations(locale.value);

  void setLanguage(String code) {
    config
      ..language = code
      ..save();
    locale.value = supportedLocale(code);
    _notify();
  }

  void setAgent(AgentProvider agent) {
    config
      ..agent = agent
      ..save();
    _notify();
  }

  void setModel(AiProvider provider, String model) {
    config
      ..aiModels[provider.name] = model.trim()
      ..save();
  }

  void setBaseUrl(AiProvider provider, String url) {
    config
      ..aiBaseUrls[provider.name] = url.trim()
      ..save();
  }

  void hide(RepoState repo) {
    config
      ..hidden.add(repo.path)
      ..save();
    _notify();
  }

  void unhide(String path) {
    config
      ..hidden.remove(path)
      ..save();
    _notify();
    unawaited(refreshRepo(path));
  }

  Future<void> _load() async {
    scanning = true;
    _notify();
    await _watch?.cancel();
    final previous = {for (final repo in _all) repo.path: repo};
    final paths = await GitWatcherService.discoverRepos(config.root, recursive: config.recursive);
    _all = [
      for (final path in paths) previous.remove(path) ?? RepoState(path, config.icons[path] ?? GitWatcherService.findIcon(path)),
    ];
    scanning = false;
    _notify();
    _watchFiles();
    await refreshAll();
    unawaited(refreshCiAll());
  }

  Future<void> rescan() => _load();

  Future<void> chooseRoot(String path) async {
    config
      ..useRoot(path)
      ..save();
    await _load();
  }

  Future<void> setRecursive(bool recursive) async {
    config
      ..recursive = recursive
      ..save();
    await _load();
  }

  void setIcon(RepoState repo, String? iconPath) {
    if (iconPath == null) {
      config.icons.remove(repo.path);
    } else {
      config.icons[repo.path] = iconPath;
    }
    config.save();
    repo.iconPath = iconPath ?? GitWatcherService.findIcon(repo.path);
    _notify();
  }

  bool isCiWatched(RepoState repo) => config.watchedCi.contains(repo.path);

  void toggleCiWatch(RepoState repo) {
    if (!config.watchedCi.remove(repo.path)) config.watchedCi.add(repo.path);
    config.save();
    _notify();
    if (isCiWatched(repo)) unawaited(refreshCi(repo));
  }

  RepoAutomationConfig? repoAutomation(RepoState repo) => config.maybeAutomation(repo.path);

  List<String> discoverSkillsFor(RepoState repo) => ai.discoverSkills(root: config.root, repo: repo.path);

  void updateRepoAutomation(
    RepoState repo,
    void Function(RepoAutomationConfig auto) edit, {
    bool resetCommitTimer = false,
    bool resetPushTimer = false,
    bool resetSkillTimer = false,
  }) {
    final auto = config.ensureAutomation(repo.path);
    edit(auto);
    if (auto.watchCommitsForSkills && (auto.lastSkillCommit == null || auto.lastSkillCommit!.isEmpty)) {
      auto.lastSkillCommit = repo.status?.headHash;
    }
    config
      ..pruneAutomation(repo.path)
      ..save();
    final now = DateTime.now();
    if (resetCommitTimer) _lastAutoCommitAt[repo.path] = now;
    if (resetPushTimer) _lastAutoPushAt[repo.path] = now;
    if (resetSkillTimer) _lastSkillCheckAt[repo.path] = now;
    clock.value = now;
    _notify();
    unawaited(_seedSkillBaseline(repo, auto));
  }

  /// Remaining time until the next scheduled auto-commit check for [repo], or `null` if disabled.
  Duration? nextAutoCommitIn(RepoState repo, {DateTime? now}) {
    final auto = config.maybeAutomation(repo.path);
    if (auto == null || !auto.autoCommit) return null;
    final current = now ?? clock.value;
    final base = _lastAutoCommitAt[repo.path] ?? _startedAt;
    final diff = base.add(Duration(minutes: auto.syncIntervalMinutes)).difference(current);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Remaining time until the next scheduled auto-push check for [repo], or `null` if disabled.
  Duration? nextAutoPushIn(RepoState repo, {DateTime? now}) {
    final auto = config.maybeAutomation(repo.path);
    if (auto == null || !auto.autoPush) return null;
    final current = now ?? clock.value;
    final base = _lastAutoPushAt[repo.path] ?? _startedAt;
    final diff = base.add(Duration(minutes: auto.pushIntervalMinutes)).difference(current);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Remaining time until the next scheduled change-check for skills on [repo], or `null` if disabled.
  Duration? nextSkillRunIn(RepoState repo, {DateTime? now}) {
    final auto = config.maybeAutomation(repo.path);
    if (auto == null || !auto.hasSkillWatch) return null;
    final current = now ?? clock.value;
    final base = _lastSkillCheckAt[repo.path] ?? _startedAt;
    final diff = base.add(Duration(minutes: auto.skillIntervalMinutes)).difference(current);
    return diff.isNegative ? Duration.zero : diff;
  }

  Future<void> _seedSkillBaselines() async {
    for (final repo in repos) {
      final auto = config.maybeAutomation(repo.path);
      if (auto != null) await _seedSkillBaseline(repo, auto);
    }
  }

  Future<void> _seedSkillBaseline(
    RepoState repo,
    RepoAutomationConfig auto,
  ) async {
    if (!auto.hasSkillWatch || (auto.lastSkillFingerprint?.isNotEmpty ?? false)) {
      return;
    }
    try {
      final status = await service.status(repo.path);
      final fingerprint = await service.changeFingerprint(repo.path, status);
      if (!auto.hasSkillWatch ||
          config.maybeAutomation(repo.path) != auto ||
          auto.hasSkillChanges(status, fingerprint)) {
        return;
      }
      _saveSkillState(auto, status, fingerprint);
    } on Object catch (error) {
      repo.error = firstLine(l10n, error);
      _notify();
    }
  }

  void _saveSkillState(
    RepoAutomationConfig auto,
    RepoStatus status,
    String fingerprint,
  ) {
    auto
      ..lastSkillCommit = status.headHash
      ..lastSkillFingerprint = fingerprint;
    config.save();
    _notify();
  }

  /// Runs auto-commit and/or auto-push for [repo] according to its settings (or explicit flags).
  Future<String> runRepoAutoSync(RepoState repo, {bool? forceCommit, bool? forcePush}) async {
    final auto = config.maybeAutomation(repo.path);
    final doCommit = forceCommit ?? auto?.autoCommit ?? false;
    final doPush = forcePush ?? auto?.autoPush ?? false;
    if (!doCommit && !doPush) return '';
    if (!_autoBusy.add(repo.path)) return '';
    try {
      await refreshRepo(repo.path);
      var status = repo.status;
      if (status == null || status.operation != RepoOperation.none) return '';
      final results = <String>[];
      if (doCommit) {
        if (status.files.isNotEmpty) {
          final summary = await commit(repo);
          results.add(summary);
          status = repo.status;
        }
        _lastAutoCommitAt[repo.path] = DateTime.now();
      }
      if (doPush && status != null) {
        final hasUnpushed = repo.ahead > 0 || (status.upstream == null && status.hasCommits);
        if (hasUnpushed) {
          await runAction(repo, l10n.appBusyAutoSync, () async {
            if (status!.remoteUrl != null && status.upstream != null) {
              await service.fetch(repo.path);
              final fresh = await service.status(repo.path);
              if (fresh.behind > 0) {
                await service.pullRebase(repo.path);
              }
            }
            final out = await service.push(repo.path);
            expectCi(repo);
            return out;
          });
          results.add(l10n.appPushedRepo(repo.name));
        }
        _lastAutoPushAt[repo.path] = DateTime.now();
      }
      clock.value = DateTime.now();
      _notify();
      return results.join(' · ');
    } finally {
      _autoBusy.remove(repo.path);
    }
  }

  /// Checks for changes immediately; unchanged repositories never start a skill.
  Future<bool> runRepoSkillsNow(RepoState repo) async {
    final auto = config.maybeAutomation(repo.path);
    if (auto == null ||
        !auto.hasActiveSkills ||
        helper.running ||
        repo.busy != null ||
        !_autoBusy.add(repo.path)) {
      return false;
    }
    try {
      return await _runSkillsIfChanged(repo, auto);
    } on Object catch (error) {
      repo.error = firstLine(l10n, error);
      return false;
    } finally {
      _autoBusy.remove(repo.path);
      final now = DateTime.now();
      _lastSkillCheckAt[repo.path] = now;
      clock.value = now;
      _notify();
    }
  }

  Future<bool> _runSkillsIfChanged(
    RepoState repo,
    RepoAutomationConfig auto,
  ) async {
    final status = await service.status(repo.path);
    repo.status = status;
    if (status.operation != RepoOperation.none) return false;
    final fingerprint = await service.changeFingerprint(repo.path, status);
    if (!auto.hasSkillChanges(status, fingerprint)) {
      if (auto.lastSkillFingerprint == null ||
          auto.lastSkillFingerprint!.isEmpty) {
        _saveSkillState(auto, status, fingerprint);
      }
      return false;
    }
    if (helper.running ||
        repo.busy != null ||
        _disposed ||
        !auto.hasActiveSkills) {
      return false;
    }
    // Persist the attempt too, so a failed release is not retried on every timer tick.
    _saveSkillState(auto, status, fingerprint);
    final ok = await helper.runSkills(repo, auto.skills);
    final after = await service.status(repo.path);
    repo.status = after;
    _saveSkillState(
      auto,
      after,
      await service.changeFingerprint(repo.path, after),
    );
    return ok;
  }

  Future<void> _tickAutomation() async {
    if (_automationTicking || scanning || _disposed) return;
    _automationTicking = true;
    try {
      final now = DateTime.now();
      for (final repo in repos) {
        if (_disposed) return;
        final auto = config.maybeAutomation(repo.path);
        if (auto == null || !auto.hasAnyAutomation) continue;

        final commitDue = auto.autoCommit &&
            now.difference(_lastAutoCommitAt[repo.path] ?? _startedAt) >= Duration(minutes: auto.syncIntervalMinutes);
        final pushDue = auto.autoPush &&
            now.difference(_lastAutoPushAt[repo.path] ?? _startedAt) >= Duration(minutes: auto.pushIntervalMinutes);

        if ((commitDue || pushDue) && repo.busy == null && !committingAll && !helper.running) {
          if (commitDue) _lastAutoCommitAt[repo.path] = now;
          if (pushDue) _lastAutoPushAt[repo.path] = now;
          clock.value = now;
          try {
            await runRepoAutoSync(repo, forceCommit: commitDue, forcePush: pushDue);
          } on Object catch (error) {
            repo.error = firstLine(l10n, error);
            _notify();
          }
        }

        if (auto.hasSkillWatch && repo.busy == null && !helper.running) {
          final lastCheck = _lastSkillCheckAt[repo.path] ?? _startedAt;
          if (now.difference(lastCheck) >= Duration(minutes: auto.skillIntervalMinutes)) {
            _lastSkillCheckAt[repo.path] = now;
            clock.value = now;
            await _checkAndRunSkills(repo, auto);
            _lastSkillCheckAt[repo.path] = DateTime.now();
          }
        }
      }
    } finally {
      _automationTicking = false;
    }
  }

  Future<void> _checkAndRunSkills(
    RepoState repo,
    RepoAutomationConfig auto,
  ) async {
    if (!_autoBusy.add(repo.path)) return;
    try {
      if (repo.remoteUrl != null) {
        try {
          await service.fetch(repo.path);
        } on Object {
          // Offline fetch failure should not prevent checking local commits.
        }
      }
      await refreshRepo(repo.path);
      if (!repo.dirty &&
          repo.behind > 0 &&
          repo.operation == RepoOperation.none) {
        try {
          await pullRebase(repo);
        } on Object catch (error) {
          repo.error = firstLine(l10n, error);
          _notify();
          return;
        }
      }
      await _runSkillsIfChanged(repo, auto);
    } on Object catch (error) {
      repo.error = firstLine(l10n, error);
      _notify();
    } finally {
      _autoBusy.remove(repo.path);
    }
  }

  Future<void> refreshAll() async {
    if (refreshing) return;
    refreshing = true;
    _notify();
    await _limited(repos, 6, (repo) => refreshRepo(repo.path));
    refreshing = false;
    _notify();
  }

  Future<void> refreshRepo(String path) async {
    final repo = byPath(path);
    if (repo == null) return;
    if (!_inFlight.add(path)) {
      _again.add(path);
      return;
    }
    try {
      final status = await service.status(path);
      repo.lines = await service.lineStats(path, status);
      repo.status = status;
      repo.error = null;
    } on Object catch (error) {
      repo.error = firstLine(l10n, error);
    } finally {
      _inFlight.remove(path);
    }
    _notify();
    if (_again.remove(path)) await refreshRepo(path);
  }

  Future<void> refreshCiAll() => _limited(repos, 4, refreshCi);

  Future<void> refreshCi(RepoState repo) async {
    final branch = repo.status?.branch;
    if (branch == null) return;
    final before = repo.ci;
    repo.ci = await ci.status(repo.path, branch);
    if (before.active && !repo.ci.active && isCiWatched(repo)) {
      unawaited(notifyMac('GIT Watcher', l10n.appCiNotification(repo.name, ciLabel(l10n, repo.ci).toLowerCase())));
    }
    _notify();
  }

  /// Running pipelines and freshly pushed repos are polled every 15 seconds so the progress bar moves.
  void _pollActiveCi() {
    final now = DateTime.now();
    for (final repo in repos) {
      if (repo.ci.active || (_fastCiUntil[repo.path]?.isAfter(now) ?? false)) unawaited(refreshCi(repo));
    }
  }

  Future<T> runAction<T>(RepoState repo, String label, Future<T> Function() action) async {
    repo.busy = label;
    _notify();
    try {
      return await action();
    } finally {
      repo.busy = null;
      _notify();
      await refreshRepo(repo.path);
    }
  }

  Future<String> commit(RepoState repo, {List<FileChange>? files}) async {
    repo.committing = true;
    try {
      return await runAction(repo, l10n.appBusyCommitting, () async {
        final targetFiles = files ?? repo.files;
        if (targetFiles.isEmpty) throw GitException(l10n.nothingToCommit);
        final text = await generateMessage(repo, subjectOnly: false, files: targetFiles);
        final hash = await service.commit(repo.path, targetFiles, text, operation: repo.operation);
        _lastAutoCommitAt[repo.path] = DateTime.now();
        final subject = text.split('\n').first.trim();
        return '${l10n.appCommitted(hash, repo.name)} · $subject';
      });
    } finally {
      repo.committing = false;
      _notify();
    }
  }

  Future<String> push(RepoState repo) => runAction(repo, 'Push…', () async {
        final output = await service.push(repo.path);
        _lastAutoPushAt[repo.path] = DateTime.now();
        expectCi(repo);
        return output;
      });

  /// Polls CI often for a while, because a push just started a new run.
  void expectCi(RepoState repo) {
    _fastCiUntil[repo.path] = DateTime.now().add(const Duration(minutes: 20));
    unawaited(Future<void>.delayed(const Duration(seconds: 8), () => refreshCi(repo)));
  }

  Future<String> fetch(RepoState repo) => runAction(repo, 'Fetch…', () => service.fetch(repo.path));
  Future<String> pullRebase(RepoState repo) => runAction(repo, 'Pull…', () => service.pullRebase(repo.path));
  Future<String> rebaseOnDefault(RepoState repo) => runAction(repo, 'Rebase…', () => service.rebaseOnDefault(repo.path));
  Future<String> sync(RepoState repo) => runAction(repo, 'Sync…', () => service.sync(repo.path));
  Future<String> stash(RepoState repo) => runAction(repo, 'Stash…', () => service.stash(repo.path));
  Future<String> stashPop(RepoState repo) => runAction(repo, 'Stash…', () => service.stashPop(repo.path));
  Future<String> continueOperation(RepoState repo) =>
      runAction(repo, l10n.appBusyContinue, () => service.continueOperation(repo.path, repo.operation));
  Future<String> abortOperation(RepoState repo) =>
      runAction(repo, l10n.appBusyAbort, () => service.abortOperation(repo.path, repo.operation));
  Future<void> discard(RepoState repo, FileChange file) =>
      runAction(repo, l10n.appBusyDiscard, () => service.discard(repo.path, file));

  Future<String> generateMessage(RepoState repo, {required bool subjectOnly, List<FileChange>? files}) async {
    final status = repo.status ?? await service.status(repo.path);
    final changes = await service.describeChanges(repo.path, files ?? status.files, hasCommits: status.hasCommits);
    final recent = (await service.log(repo.path, limit: 12)).map((c) => c.subject).toList();
    return ai.commitMessage(
      settings: config.aiSettings(aiProvider),
      repoName: repo.name,
      changes: changes,
      recentSubjects: recent,
      subjectOnly: subjectOnly,
    );
  }

  /// Writes an AI commit message and commits every dirty repo in one step.
  Future<List<String>> commitAll() async {
    if (committingAll) return const [];
    committingAll = true;
    _notify();
    final report = <String>[];
    try {
      final targets = repos.where((r) => r.dirty && r.busy == null).toList();
      // CLI sessions are slow to start and share one account, so they run one at a time.
      await _limited(targets, aiProvider.cli ? 1 : 3, (repo) async {
        try {
          await commit(repo);
          report.add(l10n.appCommittedRepo(repo.name));
        } on Object catch (error) {
          report.add('${repo.name}: ${firstLine(l10n, error)}');
        }
      });
      return report;
    } finally {
      committingAll = false;
      _notify();
    }
  }

  /// Pushes one repo at a time, because pre-push hooks can be heavy.
  Future<List<String>> pushAll() async {
    final report = <String>[];
    for (final repo in repos.where((r) => r.ahead > 0).toList()) {
      try {
        await push(repo);
        report.add(l10n.appPushedRepo(repo.name));
      } on Object catch (error) {
        report.add('${repo.name}: ${firstLine(l10n, error)}');
      }
    }
    return report;
  }

  Future<List<String>> fetchAll() async {
    if (fetching) return const [];
    fetching = true;
    _notify();
    final failures = <String>[];
    await _limited(repos, 4, (repo) async {
      try {
        await service.fetch(repo.path);
      } on Object catch (error) {
        failures.add('${repo.name}: ${firstLine(l10n, error)}');
      }
      await refreshRepo(repo.path);
    });
    fetching = false;
    _notify();
    return failures;
  }

  void _watchFiles() {
    try {
      _watch = Directory(config.root).watch(recursive: true).listen(_onFileEvent, onError: (Object _) {});
    } on FileSystemException {
      // Folder watching is unavailable here; the two-minute refresh still keeps the cards current.
    }
  }

  void _onFileEvent(FileSystemEvent event) {
    final normalized = event.path.replaceAll(r'\', '/');
    if (normalized.contains('/.git/objects/') || normalized.contains('/.git/logs/') || normalized.endsWith('.lock')) return;
    String? owner;
    for (final repo in _all) {
      final repoNorm = repo.path.replaceAll(r'\', '/');
      if ((normalized == repoNorm || normalized.startsWith('$repoNorm/')) && repo.path.length > (owner?.length ?? 0)) {
        owner = repo.path;
      }
    }
    if (owner == null || config.hidden.contains(owner)) return;
    final target = owner;
    _debounce[target]?.cancel();
    _debounce[target] = Timer(const Duration(milliseconds: 700), () => refreshRepo(target));
  }

  static Future<void> _limited<T>(List<T> items, int limit, Future<void> Function(T) work) async {
    var next = 0;
    Future<void> worker() async {
      while (next < items.length) {
        await work(items[next++]);
      }
    }

    await Future.wait([for (var i = 0; i < limit; i++) worker()]);
  }

  void notify() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in [..._timers, ..._debounce.values]) {
      timer.cancel();
    }
    unawaited(_watch?.cancel());
    clock.dispose();
    helper.dispose();
    super.dispose();
  }
}
