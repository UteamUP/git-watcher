import 'package:flutter/widgets.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../format.dart';
import 'watcher_controller.dart';

/// State of one open repo page: file selection, history, and the diff on the right.
class RepoController extends ChangeNotifier {
  RepoController(this.watcher, this.repo) : tab = repo.dirty ? 0 : 1 {
    _signature = _currentSignature();
    _head = _currentHead();
    watcher.addListener(_onWatcher);
    _loadHistory();
  }

  final WatcherController watcher;
  final RepoState repo;
  int tab;

  final excluded = <String>{};
  FileChange? selected;
  String? selectedCommit;
  FileDiff? diff;
  bool diffLoading = false;
  String? diffError;

  List<Commit> commits = const [];
  bool historyLoading = false;
  String? expanded;
  final commitFiles = <String, List<FileChange>>{};

  final message = TextEditingController();
  late String _signature;
  late String _head;
  var _disposed = false;

  List<FileChange> get files => repo.files;
  List<FileChange> get included => files.where((f) => !excluded.contains(f.path)).toList();
  bool? get allIncluded => excluded.isEmpty ? true : (included.isEmpty ? false : null);

  void setTab(int value) {
    tab = value;
    _notify();
  }

  void toggleAll() {
    if (excluded.isEmpty) {
      excluded.addAll(files.map((f) => f.path));
    } else {
      excluded.clear();
    }
    _notify();
  }

  void toggle(FileChange file) {
    if (!excluded.remove(file.path)) excluded.add(file.path);
    _notify();
  }

  Future<void> selectFile(FileChange file) => _select(file, null);

  Future<void> selectCommitFile(String hash, FileChange file) => _select(file, hash);

  Future<void> _select(FileChange file, String? hash) async {
    selected = file;
    selectedCommit = hash;
    diff = null;
    await _loadDiff();
  }

  Future<void> _loadDiff() async {
    final file = selected;
    final hash = selectedCommit;
    if (file == null) return;
    diffLoading = true;
    diffError = null;
    _notify();
    try {
      final result = hash == null
          ? await watcher.service.workingDiff(repo.path, file, hasCommits: repo.status?.hasCommits ?? true)
          : await watcher.service.commitDiff(repo.path, hash, file);
      if (selected?.path == file.path && selectedCommit == hash) diff = result;
    } on Object catch (error) {
      diffError = firstLine(watcher.l10n, error);
    }
    diffLoading = false;
    _notify();
  }

  Future<void> _loadHistory() async {
    historyLoading = true;
    _notify();
    try {
      commits = await watcher.service.log(repo.path);
    } on Object {
      commits = const [];
    }
    historyLoading = false;
    _notify();
  }

  Future<void> toggleCommit(String hash) async {
    expanded = expanded == hash ? null : hash;
    _notify();
    if (expanded != null && !commitFiles.containsKey(hash)) {
      commitFiles[hash] = await watcher.service.commitFiles(repo.path, hash);
      _notify();
    }
  }

  Future<String> commit({bool push = false}) async {
    final result = await watcher.commit(repo, files: included, message: message.text);
    message.clear();
    if (!push) return result;
    await watcher.push(repo);
    return watcher.l10n.repoCommittedAndPushed(result);
  }

  Future<void> writeMessage() => watcher.writeMessage(repo, subjectOnly: false, into: message, files: included);

  /// Reacts to the watcher only when this repo actually changed (files, line counts or HEAD).
  void _onWatcher() {
    final signature = _currentSignature();
    if (signature == _signature) return;
    _signature = signature;

    excluded.removeWhere((path) => !files.any((f) => f.path == path));
    if (selectedCommit == null && selected != null) {
      final match = files.where((f) => f.path == selected!.path).firstOrNull;
      if (match == null) {
        selected = null;
        diff = null;
      } else {
        selected = match;
        _loadDiff();
      }
    }
    final head = _currentHead();
    if (head != _head) {
      _head = head;
      _loadHistory();
    }
    _notify();
  }

  String _currentSignature() => [
        _currentHead(),
        repo.behind,
        for (final f in files) '${f.path}:${f.kind.name}:${repo.lines[f.path]?.added}:${repo.lines[f.path]?.deleted}',
      ].join('|');

  String _currentHead() => '${repo.status?.branch}|${repo.status?.lastCommitAt}|${repo.status?.lastCommitSubject}|${repo.ahead}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    watcher.removeListener(_onWatcher);
    message.dispose();
    super.dispose();
  }
}
