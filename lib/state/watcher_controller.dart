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
  bool writing = false;
  final message = TextEditingController();

  String get name => repoDisplayName(path);
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
  bool claudeReady = false;
  bool codexReady = false;

  final _inFlight = <String>{};
  final _again = <String>{};
  final _debounce = <String, Timer>{};
  final _fastCiUntil = <String, DateTime>{};
  final _timers = <Timer>[];
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
    _timers.addAll([
      Timer.periodic(const Duration(minutes: 2), (_) => refreshAll()),
      Timer.periodic(const Duration(minutes: 2), (_) => refreshCiAll()),
      Timer.periodic(const Duration(seconds: 15), (_) => _pollActiveCi()),
      Timer.periodic(const Duration(minutes: 15), (_) => fetchAll()),
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
    for (final gone in previous.values) {
      gone.message.dispose();
    }
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

  Future<String> commit(RepoState repo, {List<FileChange>? files, String? message}) =>
      runAction(repo, 'Commit…', () async {
        final text = (message ?? repo.message.text).trim();
        if (text.isEmpty) {
          throw GitException(l10n.appWriteMessageFirst);
        }
        final hash = await service.commit(repo.path, files ?? repo.files, text, operation: repo.operation);
        if (message == null) repo.message.clear();
        return l10n.appCommitted(hash, repo.name);
      });

  Future<String> push(RepoState repo) => runAction(repo, 'Push…', () async {
        final output = await service.push(repo.path);
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

  /// Lets the chosen AI write the message into [into] (the card's field by default).
  Future<void> writeMessage(RepoState repo, {bool subjectOnly = true, TextEditingController? into, List<FileChange>? files}) async {
    if (repo.writing) return;
    repo.writing = true;
    _notify();
    try {
      (into ?? repo.message).text = await generateMessage(repo, subjectOnly: subjectOnly, files: files);
    } finally {
      repo.writing = false;
      _notify();
    }
  }

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

  Future<List<String>> writeAllMessages() async {
    final failures = <String>[];
    final targets = repos.where((r) => r.dirty && r.message.text.trim().isEmpty).toList();
    // CLI sessions are slow to start and share one account, so they run one at a time.
    await _limited(targets, aiProvider.cli ? 1 : 3, (repo) async {
      try {
        await writeMessage(repo);
      } on Object catch (error) {
        failures.add('${repo.name}: ${firstLine(l10n, error)}');
      }
    });
    return failures;
  }

  /// Commits every repo that has a message written; the rest are listed as skipped.
  Future<List<String>> commitAll() async {
    final report = <String>[];
    for (final repo in repos.where((r) => r.dirty).toList()) {
      if (repo.message.text.trim().isEmpty) {
        report.add(l10n.appSkippedNoMessage(repo.name));
        continue;
      }
      try {
        await commit(repo);
        report.add(l10n.appCommittedRepo(repo.name));
      } on Object catch (error) {
        report.add('${repo.name}: ${firstLine(l10n, error)}');
      }
    }
    return report;
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
    final path = event.path;
    if (path.contains('/.git/objects/') || path.contains('/.git/logs/') || path.endsWith('.lock')) return;
    String? owner;
    for (final repo in _all) {
      if ((path == repo.path || path.startsWith('${repo.path}/')) && repo.path.length > (owner?.length ?? 0)) {
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
    for (final repo in _all) {
      repo.message.dispose();
    }
    helper.dispose();
    super.dispose();
  }
}
