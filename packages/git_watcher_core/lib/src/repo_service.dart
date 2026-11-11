import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'git.dart';
import 'models.dart';
import 'parsers.dart';

/// Folders that never hold a repository worth watching but can be huge.
const _skipDirs = {
  'node_modules', 'build', 'dist', 'bin', 'obj', '.dart_tool', 'Pods', 'DerivedData',
  '.next', '.nuxt', '.output', 'target', 'vendor', 'venv', '.venv', '__pycache__',
  'coverage', '.gradle',
};

/// Known places a project keeps its own app icon or logo, best first.
const _iconCandidates = [
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png',
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png',
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
  'public/apple-touch-icon.png',
  'public/logo.png',
  'public/logo.svg',
  'public/favicon.png',
  'public/favicon.svg',
  'assets/images/logo.png',
  'assets/logo.png',
  'assets/icon.png',
  'assets/icon.svg',
  'web/favicon.png',
  'icon.png',
  'logo.png',
];

class GitWatcherService {
  GitWatcherService(this.git);

  final Git git;
  final _gitDirs = <String, String>{};

  /// Every git repository under [root]: the root itself, then its folders.
  /// Repositories below the root are not searched further, because nested
  /// repos are rare and their build folders are large.
  static Future<List<String>> discoverRepos(String root, {bool recursive = true, int maxDepth = 5}) async {
    final base = root.length > 1 && root.endsWith('/') ? root.substring(0, root.length - 1) : root;
    final repos = <String>[];
    if (!await Directory(base).exists()) return repos;

    Future<void> walk(String dir, int depth) async {
      final isRepo = await isRepository(dir);
      if (isRepo) repos.add(dir);
      if ((isRepo && dir != base) || depth >= (recursive ? maxDepth : 1)) return;

      final List<FileSystemEntity> children;
      try {
        children = await Directory(dir).list(followLinks: false).toList();
      } on FileSystemException {
        return;
      }
      await Future.wait([
        for (final child in children)
          if (child is Directory && !_hidden(child.path)) walk(child.path, depth + 1),
      ]);
    }

    await walk(base, 0);
    repos.sort((a, b) {
      if (a == base) return -1;
      if (b == base) return 1;
      return repoDisplayName(a).toLowerCase().compareTo(repoDisplayName(b).toLowerCase());
    });
    return repos;
  }

  static bool _hidden(String path) {
    final name = path.split('/').last;
    return name.startsWith('.') || _skipDirs.contains(name);
  }

  static Future<bool> isRepository(String path) async =>
      await FileSystemEntity.type('$path/.git') != FileSystemEntityType.notFound;

  /// The project's own icon or logo file, if it ships one in a known place.
  static String? findIcon(String repo) {
    for (final candidate in _iconCandidates) {
      final file = File('$repo/$candidate');
      if (file.existsSync()) return file.path;
    }
    final components = Directory('$repo/custom_components');
    if (components.existsSync()) {
      for (final dir in components.listSync().whereType<Directory>()) {
        final icon = File('${dir.path}/brand/icon.png');
        if (icon.existsSync()) return icon.path;
      }
    }
    return null;
  }

  Future<RepoStatus> status(String repo) async {
    final statusOut = git.check(repo, ['status', '--porcelain=v2', '--branch', '-z', '--untracked-files=all']);
    final lastCommit = git.run(repo, ['log', '-1', '--format=%ct%x1f%s']);
    final operation = await _operation(repo);
    final parsed = parseStatusV2((await statusOut).stdout);

    DateTime? lastAt;
    String? lastSubject;
    final log = await lastCommit;
    if (log.ok && log.stdout.trim().isNotEmpty) {
      final fields = log.stdout.trim().split('\x1f');
      lastAt = DateTime.fromMillisecondsSinceEpoch((int.tryParse(fields[0]) ?? 0) * 1000);
      lastSubject = fields.length > 1 ? fields[1] : null;
    }

    return RepoStatus(
      branch: parsed.branch,
      upstream: parsed.upstream,
      ahead: parsed.ahead,
      behind: parsed.behind,
      hasCommits: parsed.hasCommits,
      files: parsed.files,
      operation: operation,
      lastCommitAt: lastAt,
      lastCommitSubject: lastSubject,
    );
  }

  Future<RepoOperation> _operation(String repo) async {
    final gitDir = _gitDirs[repo] ??= (await git.check(repo, ['rev-parse', '--absolute-git-dir'])).stdout.trim();
    if (await Directory('$gitDir/rebase-merge').exists() || await Directory('$gitDir/rebase-apply').exists()) {
      return RepoOperation.rebase;
    }
    if (await File('$gitDir/MERGE_HEAD').exists()) return RepoOperation.merge;
    if (await File('$gitDir/CHERRY_PICK_HEAD').exists()) return RepoOperation.cherryPick;
    return RepoOperation.none;
  }

  /// Line counts per changed file, untracked files counted as all-new lines.
  Future<Map<String, LineStat>> lineStats(String repo, RepoStatus status) async {
    final stats = <String, LineStat>{};
    if (status.hasCommits) {
      stats.addAll(parseNumstat((await git.check(repo, ['diff', 'HEAD', '--numstat', '-z', '-M'])).stdout));
    }
    final untracked = status.files.where((f) => f.kind == ChangeKind.untracked).take(400);
    for (final file in untracked) {
      stats[file.path] = await _countLines('$repo/${file.path}');
    }
    return stats;
  }

  static Future<LineStat> _countLines(String path) async {
    try {
      final file = File(path);
      if (await file.length() > 2 * 1024 * 1024) return const LineStat(null, null);
      final bytes = await file.readAsBytes();
      if (bytes.take(8000).contains(0)) return const LineStat(null, null);
      final lines = bytes.where((b) => b == 10).length + (bytes.isNotEmpty && bytes.last != 10 ? 1 : 0);
      return LineStat(lines, 0);
    } on FileSystemException {
      return const LineStat(null, null);
    }
  }

  Future<List<Commit>> log(String repo, {int limit = 150}) async {
    final out = await git.run(repo, ['log', '-n', '$limit', '--format=$logFormat']);
    if (!out.ok) return const [];
    final remotes = (await git.run(repo, ['remote'])).stdout.trim();
    var unpushed = <String>{};
    if (remotes.isNotEmpty) {
      final rev = await git.run(repo, ['rev-list', '-n', '$limit', 'HEAD', '--not', '--remotes']);
      if (rev.ok) unpushed = rev.stdout.split('\n').where((l) => l.isNotEmpty).toSet();
    }
    return parseLog(out.stdout, unpushed);
  }

  Future<List<FileChange>> commitFiles(String repo, String hash) async => parseNameStatus(
      (await git.check(repo, ['show', '--diff-merges=first-parent', '--format=', '--name-status', '-z', '-M', hash]))
          .stdout);

  Future<String> rawWorkingDiff(String repo, FileChange file, {required bool hasCommits}) async {
    if (file.kind == ChangeKind.untracked || !hasCommits) {
      final f = File('$repo/${file.path}');
      if (!await f.exists()) return '';
      final bytes = await f.readAsBytes();
      if (bytes.take(8000).contains(0)) return 'Binary file ${file.path}';
      return utf8.decode(bytes, allowMalformed: true);
    }
    return (await git.check(repo, ['diff', 'HEAD', '-M', '--', ...file.pathspecs])).stdout;
  }

  Future<FileDiff> workingDiff(String repo, FileChange file, {required bool hasCommits}) async {
    if (file.kind == ChangeKind.untracked || !hasCommits) return fileAsAdded('$repo/${file.path}');
    return parseUnifiedDiff((await git.check(repo, ['diff', 'HEAD', '-M', '--', ...file.pathspecs])).stdout);
  }

  Future<String> rawCommitDiff(String repo, String hash, FileChange file) async => (await git.check(
          repo, ['show', '--diff-merges=first-parent', '--format=', '-M', hash, '--', ...file.pathspecs]))
      .stdout;

  Future<FileDiff> commitDiff(String repo, String hash, FileChange file) async =>
      parseUnifiedDiff(await rawCommitDiff(repo, hash, file));

  static Future<FileDiff> fileAsAdded(String path, {int maxLines = 20000}) async {
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.notFound) return const FileDiff.notice(DiffNotice.missing);
    if (type == FileSystemEntityType.directory) return const FileDiff.notice(DiffNotice.directory);
    final file = File(path);
    if (await file.length() > 5 * 1024 * 1024) return const FileDiff.notice(DiffNotice.tooLarge);
    final bytes = await file.readAsBytes();
    if (bytes.take(8000).contains(0)) return const FileDiff.notice(DiffNotice.binary);
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = text.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    if (lines.isEmpty) return const FileDiff.notice(DiffNotice.empty);
    final shown = lines.take(maxLines).toList();
    return FileDiff(
      lines: [
        DiffLine(DiffLineType.hunk, '@@ -0,0 +1,${lines.length} @@'),
        for (var i = 0; i < shown.length; i++) DiffLine(DiffLineType.added, shown[i], newLine: i + 1),
      ],
      truncated: lines.length > maxLines,
    );
  }

  /// Stages exactly [files] and commits only them, leaving other staged work alone.
  Future<String> commit(String repo, List<FileChange> files, String message, {RepoOperation? operation}) async {
    if (files.isEmpty) throw const GitException('No files selected to commit');
    if (message.trim().isEmpty) throw const GitException('The commit message is empty');
    final paths = {for (final f in files) ...f.pathspecs};
    // Staged deletions and rename sources no longer exist in the index or worktree.
    final stageable = (await git.check(repo, ['ls-files', '--cached', '--others', '--exclude-standard', '-z']))
        .stdout.split('\x00').toSet();
    final stageSpec = paths.where(stageable.contains).join('\x00');
    if (stageSpec.isNotEmpty) {
      await git.check(repo, ['add', '-A', '--pathspec-from-file=-', '--pathspec-file-nul'], stdin: stageSpec);
    }
    final spec = paths.join('\x00');
    // A merge or rebase in progress refuses a partial commit, so commit the whole index then.
    final partial = (operation ?? await _operation(repo)) == RepoOperation.none;
    await git.check(
      repo,
      ['commit', '-m', message.trim(), if (partial) ...['--pathspec-from-file=-', '--pathspec-file-nul']],
      stdin: partial ? spec : null,
      timeout: const Duration(minutes: 15),
    );
    return (await git.check(repo, ['rev-parse', '--short', 'HEAD'])).stdout.trim();
  }

  Future<String> push(String repo) async {
    final upstream = await git.run(repo, ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}']);
    if (upstream.ok) {
      return (await git.check(repo, ['push'], timeout: const Duration(minutes: 30))).combined;
    }
    final remotes = (await git.check(repo, ['remote'])).stdout.split('\n').where((r) => r.isNotEmpty).toList();
    if (remotes.isEmpty) throw const GitException('This repository has no remote to push to');
    final remote = remotes.contains('origin') ? 'origin' : remotes.first;
    return (await git.check(repo, ['push', '-u', remote, 'HEAD'], timeout: const Duration(minutes: 30))).combined;
  }

  Future<String> pullRebase(String repo) async =>
      (await git.check(repo, ['pull', '--rebase', '--autostash'], timeout: const Duration(minutes: 10))).combined;

  /// Rebases the current branch onto the remote default branch (origin/main or origin/master).
  Future<String> rebaseOnDefault(String repo) async {
    await git.check(repo, ['fetch', '--prune'], timeout: const Duration(minutes: 5));
    final head = await git.run(repo, ['symbolic-ref', '--short', 'refs/remotes/origin/HEAD']);
    final target = head.ok ? head.stdout.trim() : 'origin/main';
    return (await git.check(repo, ['rebase', '--autostash', target], timeout: const Duration(minutes: 10))).combined;
  }

  Future<String> fetch(String repo) async =>
      (await git.check(repo, ['fetch', '--all', '--prune'], timeout: const Duration(minutes: 5))).combined;

  Future<String> sync(String repo) async {
    final pulled = await pullRebase(repo);
    final pushed = await push(repo);
    return [pulled, pushed].where((s) => s.isNotEmpty).join('\n');
  }

  Future<String> stash(String repo) async => (await git.check(
          repo, ['stash', 'push', '--include-untracked', '-m', 'GIT Watcher ${DateTime.now().toIso8601String()}']))
      .combined;

  Future<String> stashPop(String repo) async => (await git.check(repo, ['stash', 'pop'])).combined;

  Future<String> continueOperation(String repo, RepoOperation operation) async {
    final command = switch (operation) {
      RepoOperation.merge => ['commit', '--no-edit'],
      RepoOperation.cherryPick => ['cherry-pick', '--continue'],
      _ => ['rebase', '--continue'],
    };
    return (await git.check(repo, command)).combined;
  }

  Future<String> abortOperation(String repo, RepoOperation operation) async {
    final command = switch (operation) {
      RepoOperation.merge => ['merge', '--abort'],
      RepoOperation.cherryPick => ['cherry-pick', '--abort'],
      _ => ['rebase', '--abort'],
    };
    return (await git.check(repo, command)).combined;
  }

  /// Throws away the working change to [file]. New files go to the Trash, not oblivion.
  Future<void> discard(String repo, FileChange file) async {
    switch (file.kind) {
      case ChangeKind.untracked:
        await _trash('$repo/${file.path}');
      case ChangeKind.added:
        await git.check(repo, ['rm', '--cached', '--quiet', '--', file.path]);
        await _trash('$repo/${file.path}');
      case ChangeKind.renamed:
        await git.check(repo, ['restore', '--source=HEAD', '--staged', '--worktree', '--', file.originalPath!]);
        await git.check(repo, ['rm', '--cached', '--quiet', '--ignore-unmatch', '--', file.path]);
        await _trash('$repo/${file.path}');
      default:
        await git.check(repo, ['restore', '--source=HEAD', '--staged', '--worktree', '--', file.path]);
    }
  }

  Future<void> _trash(String path) async {
    if (!await File(path).exists() && !await Directory(path).exists()) return;
    final result = await Process.run('/usr/bin/trash', [path]);
    if (result.exitCode != 0) throw GitException('Could not move $path to the Trash: ${result.stderr}');
  }

  /// Diff text for an AI to describe: stat, patch (truncated) and a peek at new files.
  Future<String> describeChanges(String repo, List<FileChange> files, {required bool hasCommits, int maxChars = 60000}) async {
    final buffer = StringBuffer();
    final tracked = files.where((f) => f.kind != ChangeKind.untracked).expand((f) => f.pathspecs).toList();
    if (hasCommits && tracked.isNotEmpty) {
      buffer.writeln((await git.check(repo, ['diff', 'HEAD', '--stat=120', '-M', '--', ...tracked])).stdout);
      buffer.writeln((await git.check(repo, ['diff', 'HEAD', '-M', '--', ...tracked])).stdout);
    }
    final untracked = files.where((f) => f.kind == ChangeKind.untracked || !hasCommits).toList();
    if (untracked.isNotEmpty) {
      buffer.writeln('New files:');
      for (final file in untracked) {
        buffer.writeln('  ${file.path}');
      }
      for (final file in untracked.take(12)) {
        final added = await fileAsAdded('$repo/${file.path}', maxLines: 40);
        if (added.lines.isEmpty) continue;
        buffer.writeln('--- ${file.path} (new, first lines)');
        for (final line in added.lines.skip(1)) {
          buffer.writeln('+${line.text}');
        }
      }
    }
    final text = buffer.toString();
    return text.length > maxChars ? '${text.substring(0, maxChars)}\n[diff truncated]' : text;
  }
}
