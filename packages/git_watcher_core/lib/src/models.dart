import 'dart:io';

enum ChangeKind { modified, added, deleted, renamed, untracked, conflicted }

extension ChangeKindLetter on ChangeKind {
  String get letter => switch (this) {
        ChangeKind.modified => 'M',
        ChangeKind.added => 'A',
        ChangeKind.deleted => 'D',
        ChangeKind.renamed => 'R',
        ChangeKind.untracked => 'U',
        ChangeKind.conflicted => '!',
      };
}

enum RepoOperation { none, rebase, merge, cherryPick }

String repoFolderName(String path) {
  final parts = path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).toList();
  return parts.isEmpty ? path : parts.last;
}

/// "UteamUP_Backend" reads as "Backend" on a card; other folders keep their name.
String repoDisplayName(String path) {
  final name = repoFolderName(path);
  return name.startsWith('UteamUP_') ? name.substring('UteamUP_'.length) : name;
}

/// Normalizes a local filesystem path to the OS's native separator (`\` on Windows, `/` on macOS).
String formatDiskPath(String path, {bool? windows}) {
  final win = windows ?? Platform.isWindows;
  final sep = win ? r'\' : '/';
  final normalized = path.replaceAll(RegExp(r'[/\\]+'), sep);
  if (normalized.length > 1 && normalized.endsWith(sep) && !(win && RegExp(r'^[A-Za-z]:\\$').hasMatch(normalized))) {
    return normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

class FileChange {
  const FileChange({
    required this.path,
    required this.kind,
    this.originalPath,
    this.staged = false,
    this.unstaged = false,
  });

  final String path;
  final String? originalPath;
  final ChangeKind kind;
  final bool staged;
  final bool unstaged;

  String get fileName => path.split(RegExp(r'[/\\]')).last;

  String get directory {
    final slash = path.lastIndexOf(RegExp(r'[/\\]'));
    return slash < 0 ? '' : path.substring(0, slash);
  }

  /// Every path git needs to see to stage or restore this change (both sides of a rename).
  List<String> get pathspecs => [path, ?originalPath];

  Map<String, Object?> toJson() => {
        'path': path,
        'originalPath': ?originalPath,
        'kind': kind.name,
        'staged': staged,
        'unstaged': unstaged,
      };
}

class RepoStatus {
  const RepoStatus({
    required this.branch,
    required this.upstream,
    required this.ahead,
    required this.behind,
    required this.hasCommits,
    required this.files,
    this.remoteUrl,
    this.operation = RepoOperation.none,
    this.headHash,
    this.lastCommitAt,
    this.lastCommitSubject,
  });

  final String branch;
  final String? upstream;
  final String? remoteUrl;
  final int ahead;
  final int behind;
  final bool hasCommits;
  final List<FileChange> files;
  final RepoOperation operation;
  final String? headHash;
  final DateTime? lastCommitAt;
  final String? lastCommitSubject;

  bool get isClean => files.isEmpty;

  int count(ChangeKind kind) => files.where((f) => f.kind == kind).length;

  Map<ChangeKind, int> get counts => {
        for (final kind in ChangeKind.values)
          if (count(kind) > 0) kind: count(kind),
      };

  Map<String, Object?> toJson({bool includeFiles = true}) => {
        'branch': branch,
        'upstream': upstream,
        if (remoteUrl != null) 'remoteUrl': remoteUrl,
        'ahead': ahead,
        'behind': behind,
        'hasCommits': hasCommits,
        'operation': operation.name,
        'changedFiles': files.length,
        'counts': {for (final e in counts.entries) e.key.name: e.value},
        if (headHash != null) 'headHash': headHash,
        'lastCommitAt': lastCommitAt?.toIso8601String(),
        'lastCommitSubject': lastCommitSubject,
        if (includeFiles) 'files': [for (final f in files) f.toJson()],
      };
}

class Commit {
  const Commit({
    required this.hash,
    required this.shortHash,
    required this.author,
    required this.email,
    required this.date,
    required this.subject,
    required this.parents,
    required this.pushed,
  });

  final String hash;
  final String shortHash;
  final String author;
  final String email;
  final DateTime date;
  final String subject;
  final List<String> parents;
  final bool pushed;

  bool get isMerge => parents.length > 1;

  Map<String, Object?> toJson() => {
        'hash': hash,
        'shortHash': shortHash,
        'author': author,
        'email': email,
        'date': date.toIso8601String(),
        'subject': subject,
        'pushed': pushed,
        if (isMerge) 'merge': true,
      };
}

/// Added/deleted line counts; both null for binary files.
class LineStat {
  const LineStat(this.added, this.deleted);

  final int? added;
  final int? deleted;

  bool get binary => added == null;
}

enum DiffLineType { hunk, context, added, removed, note }

class DiffLine {
  const DiffLine(this.type, this.text, {this.oldLine, this.newLine});

  final DiffLineType type;
  final String text;
  final int? oldLine;
  final int? newLine;
}

/// Why a diff has no lines to show.
enum DiffNotice { none, binary, missing, directory, tooLarge, empty }

class FileDiff {
  const FileDiff({required this.lines, this.notice = DiffNotice.none, this.truncated = false});

  const FileDiff.notice(this.notice)
      : lines = const [],
        truncated = false;

  final List<DiffLine> lines;
  final DiffNotice notice;
  final bool truncated;

  int get additions => lines.where((l) => l.type == DiffLineType.added).length;
  int get deletions => lines.where((l) => l.type == DiffLineType.removed).length;
}
