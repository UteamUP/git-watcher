import 'models.dart';

typedef ParsedStatus = ({
  String branch,
  String? upstream,
  int ahead,
  int behind,
  bool hasCommits,
  List<FileChange> files,
});

/// Parses `git status --porcelain=v2 --branch -z`.
ParsedStatus parseStatusV2(String output) {
  var branch = 'HEAD';
  String? upstream;
  var ahead = 0;
  var behind = 0;
  var hasCommits = true;
  final files = <FileChange>[];
  final tokens = output.split('\x00');

  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.isEmpty) continue;

    if (token.startsWith('# ')) {
      final header = _splitN(token.substring(2), 2);
      final value = header.length > 1 ? header[1] : '';
      switch (header[0]) {
        case 'branch.oid':
          hasCommits = value != '(initial)';
        case 'branch.head':
          branch = value == '(detached)' ? 'HEAD (detached)' : value;
        case 'branch.upstream':
          upstream = value;
        case 'branch.ab':
          final ab = value.split(' ');
          ahead = int.tryParse(ab[0].replaceFirst('+', '')) ?? 0;
          behind = int.tryParse(ab.length > 1 ? ab[1].replaceFirst('-', '') : '') ?? 0;
      }
    } else if (token.startsWith('1 ')) {
      final parts = _splitN(token, 9);
      files.add(_tracked(parts[1], parts[8]));
    } else if (token.startsWith('2 ')) {
      final parts = _splitN(token, 10);
      final original = i + 1 < tokens.length ? tokens[++i] : null;
      files.add(FileChange(
        path: parts[9],
        originalPath: original,
        kind: ChangeKind.renamed,
        staged: parts[1][0] != '.',
        unstaged: parts[1][1] != '.',
      ));
    } else if (token.startsWith('u ')) {
      final parts = _splitN(token, 11);
      files.add(FileChange(path: parts[10], kind: ChangeKind.conflicted, unstaged: true));
    } else if (token.startsWith('? ')) {
      files.add(FileChange(path: token.substring(2), kind: ChangeKind.untracked, unstaged: true));
    }
  }

  files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  return (
    branch: branch,
    upstream: upstream,
    ahead: ahead,
    behind: behind,
    hasCommits: hasCommits,
    files: files,
  );
}

FileChange _tracked(String xy, String path) {
  final kind = xy.contains('D')
      ? ChangeKind.deleted
      : xy.contains('A')
          ? ChangeKind.added
          : ChangeKind.modified;
  return FileChange(path: path, kind: kind, staged: xy[0] != '.', unstaged: xy[1] != '.');
}

/// Splits on single spaces into at most [n] parts; the last part keeps any spaces (file paths).
List<String> _splitN(String value, int n) {
  final parts = <String>[];
  var start = 0;
  while (parts.length < n - 1) {
    final space = value.indexOf(' ', start);
    if (space < 0) break;
    parts.add(value.substring(start, space));
    start = space + 1;
  }
  parts.add(value.substring(start));
  return parts;
}

/// Parses `git diff --numstat -z`, keyed by the new path.
Map<String, LineStat> parseNumstat(String output) {
  final stats = <String, LineStat>{};
  final tokens = output.split('\x00');
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i].replaceFirst(RegExp(r'^\n'), '');
    if (token.isEmpty) continue;
    final parts = token.split('\t');
    if (parts.length < 3) continue;
    var path = parts[2];
    if (path.isEmpty && i + 2 < tokens.length) {
      i += 2;
      path = tokens[i];
    }
    stats[path] = LineStat(int.tryParse(parts[0]), int.tryParse(parts[1]));
  }
  return stats;
}

/// Format used with [parseLog].
const logFormat = '%H%x1f%h%x1f%an%x1f%ae%x1f%ct%x1f%P%x1f%s%x1e';

List<Commit> parseLog(String output, Set<String> unpushed) {
  final commits = <Commit>[];
  for (final record in output.split('\x1e')) {
    final fields = record.trim().split('\x1f');
    if (fields.length < 7) continue;
    commits.add(Commit(
      hash: fields[0],
      shortHash: fields[1],
      author: fields[2],
      email: fields[3],
      date: DateTime.fromMillisecondsSinceEpoch((int.tryParse(fields[4]) ?? 0) * 1000),
      parents: fields[5].split(' ').where((p) => p.isNotEmpty).toList(),
      subject: fields.sublist(6).join('\x1f'),
      pushed: !unpushed.contains(fields[0]),
    ));
  }
  return commits;
}

/// Parses `git show --name-status -z` for the files touched by one commit.
List<FileChange> parseNameStatus(String output) {
  final files = <FileChange>[];
  final tokens = output.split('\x00');
  for (var i = 0; i < tokens.length; i++) {
    final status = tokens[i].trim();
    if (status.isEmpty) continue;
    final code = status[0];
    if ((code == 'R' || code == 'C') && i + 2 < tokens.length) {
      final original = tokens[++i];
      final path = tokens[++i];
      files.add(FileChange(
        path: path,
        originalPath: code == 'R' ? original : null,
        kind: code == 'R' ? ChangeKind.renamed : ChangeKind.added,
      ));
    } else if (i + 1 < tokens.length) {
      final path = tokens[++i];
      final kind = switch (code) {
        'A' => ChangeKind.added,
        'D' => ChangeKind.deleted,
        'U' => ChangeKind.conflicted,
        _ => ChangeKind.modified,
      };
      files.add(FileChange(path: path, kind: kind));
    }
  }
  return files;
}

final _hunkHeader = RegExp(r'^@@+ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@+');

/// Turns a unified diff into display lines with old/new line numbers.
FileDiff parseUnifiedDiff(String output, {int maxLines = 20000}) {
  if (output.trim().isEmpty) return const FileDiff.notice(DiffNotice.empty);

  final lines = <DiffLine>[];
  var inHeader = true;
  var binary = false;
  var oldLine = 0;
  var newLine = 0;

  for (final line in output.split('\n')) {
    if (lines.length >= maxLines) {
      return FileDiff(lines: lines, truncated: true);
    }
    if (line.startsWith('diff --git ') || line.startsWith('diff --cc ')) {
      inHeader = true;
      continue;
    }
    if (line.startsWith('Binary files ') || line == 'GIT binary patch') {
      binary = true;
      continue;
    }
    final hunk = _hunkHeader.firstMatch(line);
    if (hunk != null) {
      inHeader = false;
      oldLine = int.parse(hunk.group(1)!);
      newLine = int.parse(hunk.group(2)!);
      lines.add(DiffLine(DiffLineType.hunk, line));
      continue;
    }
    if (inHeader || line.isEmpty) continue;

    final text = line.substring(1);
    switch (line[0]) {
      case '+':
        lines.add(DiffLine(DiffLineType.added, text, newLine: newLine++));
      case '-':
        lines.add(DiffLine(DiffLineType.removed, text, oldLine: oldLine++));
      case '\\':
        lines.add(DiffLine(DiffLineType.note, line.substring(2)));
      default:
        lines.add(DiffLine(DiffLineType.context, text, oldLine: oldLine++, newLine: newLine++));
    }
  }

  if (lines.isEmpty) return FileDiff.notice(binary ? DiffNotice.binary : DiffNotice.empty);
  return FileDiff(lines: lines);
}
