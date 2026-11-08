import 'package:git_watcher_core/git_watcher_core.dart';
import 'package:test/test.dart';

void main() {
  group('parseStatusV2', () {
    test('reads branch, upstream, ahead and behind', () {
      final status = parseStatusV2(
          '# branch.oid abc\x00# branch.head main\x00# branch.upstream origin/main\x00# branch.ab +13 -2\x00');
      expect(status.branch, 'main');
      expect(status.upstream, 'origin/main');
      expect(status.ahead, 13);
      expect(status.behind, 2);
      expect(status.hasCommits, isTrue);
      expect(status.files, isEmpty);
    });

    test('marks a repository without commits and a detached head', () {
      final status = parseStatusV2('# branch.oid (initial)\x00# branch.head (detached)\x00');
      expect(status.hasCommits, isFalse);
      expect(status.branch, 'HEAD (detached)');
      expect(status.upstream, isNull);
    });

    test('classifies modified, added, deleted, renamed, untracked and conflicted files', () {
      final status = parseStatusV2([
        '1 .M N... 100644 100644 100644 a a src/edit me.dart',
        '1 A. N... 000000 100644 100644 0 b new.txt',
        '1 .D N... 100644 100644 000000 c c gone.txt',
        '2 R. N... 100644 100644 100644 d d R100 renamed/to.txt',
        'renamed/from.txt',
        'u UU N... 100644 100644 100644 100644 e f g conflict.txt',
        '? untracked file.md',
        '',
      ].join('\x00'));
      final byPath = {for (final f in status.files) f.path: f};
      expect(byPath['src/edit me.dart']!.kind, ChangeKind.modified);
      expect(byPath['src/edit me.dart']!.unstaged, isTrue);
      expect(byPath['src/edit me.dart']!.staged, isFalse);
      expect(byPath['new.txt']!.kind, ChangeKind.added);
      expect(byPath['gone.txt']!.kind, ChangeKind.deleted);
      expect(byPath['renamed/to.txt']!.kind, ChangeKind.renamed);
      expect(byPath['renamed/to.txt']!.originalPath, 'renamed/from.txt');
      expect(byPath['renamed/to.txt']!.pathspecs, ['renamed/to.txt', 'renamed/from.txt']);
      expect(byPath['conflict.txt']!.kind, ChangeKind.conflicted);
      expect(byPath['untracked file.md']!.kind, ChangeKind.untracked);
      expect(status.files, hasLength(6));
    });
  });

  test('parseNumstat handles renames and binary files', () {
    final stats = parseNumstat('3\t1\tlib/a.dart\x00-\t-\timage.png\x0010\t0\t\x00old.txt\x00new.txt\x00');
    expect(stats['lib/a.dart']!.added, 3);
    expect(stats['lib/a.dart']!.deleted, 1);
    expect(stats['image.png']!.binary, isTrue);
    expect(stats['new.txt']!.added, 10);
    expect(stats.containsKey('old.txt'), isFalse);
  });

  test('parseLog keeps subjects with separators and marks unpushed commits', () {
    final out = 'aaa\x1fa1\x1fAnna\x1fanna@x.is\x1f1700000000\x1fppp\x1ffeat: one\x1e\n'
        'bbb\x1fb2\x1fBen\x1fben@x.is\x1f1700000100\x1fccc ddd\x1fmerge: two\x1e\n';
    final commits = parseLog(out, {'aaa'});
    expect(commits, hasLength(2));
    expect(commits.first.subject, 'feat: one');
    expect(commits.first.pushed, isFalse);
    expect(commits.last.pushed, isTrue);
    expect(commits.last.isMerge, isTrue);
  });

  test('parseNameStatus reads renames, copies and deletions', () {
    final files = parseNameStatus('M\x00a.txt\x00R087\x00old.txt\x00new.txt\x00D\x00gone.txt\x00C100\x00src.txt\x00copy.txt\x00');
    expect(files.map((f) => f.kind), [ChangeKind.modified, ChangeKind.renamed, ChangeKind.deleted, ChangeKind.added]);
    expect(files[1].originalPath, 'old.txt');
    expect(files[3].path, 'copy.txt');
  });

  group('parseUnifiedDiff', () {
    test('numbers lines and treats a removed "-- x" line as content, not a header', () {
      final diff = parseUnifiedDiff([
        'diff --git a/f.txt b/f.txt',
        'index 1..2 100644',
        '--- a/f.txt',
        '+++ b/f.txt',
        '@@ -10,3 +10,3 @@ section',
        ' keep',
        '--- old comment',
        '+new line',
        '\\ No newline at end of file',
        '',
      ].join('\n'));
      expect(diff.lines.map((l) => l.type), [
        DiffLineType.hunk,
        DiffLineType.context,
        DiffLineType.removed,
        DiffLineType.added,
        DiffLineType.note,
      ]);
      expect(diff.lines[1].oldLine, 10);
      expect(diff.lines[1].newLine, 10);
      expect(diff.lines[2].text, '-- old comment');
      expect(diff.lines[2].oldLine, 11);
      expect(diff.lines[3].newLine, 11);
      expect(diff.additions, 1);
      expect(diff.deletions, 1);
    });

    test('reports binary and empty diffs as notices', () {
      expect(parseUnifiedDiff('diff --git a/x b/x\nBinary files a/x and b/x differ\n').notice, DiffNotice.binary);
      expect(parseUnifiedDiff('').notice, DiffNotice.empty);
    });

    test('stops at the line limit', () {
      final body = List.generate(50, (i) => '+line $i').join('\n');
      final diff = parseUnifiedDiff('@@ -0,0 +1,50 @@\n$body\n', maxLines: 10);
      expect(diff.truncated, isTrue);
      expect(diff.lines, hasLength(10));
    });
  });

  test('CI time left uses the median of past successful runs of the same workflow', () {
    Map<String, dynamic> run(String workflow, String start, int minutes, {String conclusion = 'success'}) => {
          'workflowName': workflow,
          'status': 'completed',
          'conclusion': conclusion,
          'createdAt': start,
          'updatedAt': DateTime.parse(start).add(Duration(minutes: minutes)).toIso8601String(),
        };
    final history = [
      run('CI', '2026-11-01T10:00:00Z', 8),
      run('CI', '2026-11-02T10:00:00Z', 10),
      run('CI', '2026-11-03T10:00:00Z', 30, conclusion: 'failure'),
      run('CI', '2026-11-04T10:00:00Z', 12),
      run('Release', '2026-11-04T10:00:00Z', 2),
    ];
    final active = [
      {'workflowName': 'CI', 'status': 'in_progress', 'createdAt': '2026-11-08T12:00:00Z'},
      {'workflowName': 'Release', 'status': 'in_progress', 'createdAt': '2026-11-08T12:00:00Z'},
    ];
    expect(CiService.estimateEnd(active, history), DateTime.parse('2026-11-08T12:10:00Z'));
    expect(CiService.estimateEnd([{'workflowName': 'New', 'createdAt': '2026-11-08T12:00:00Z'}], history), isNull);
  });

  test('CI leaves out GitHub dynamic runs such as Dependabot updates', () {
    final runs = [
      {'databaseId': 3, 'headSha': 'abc', 'event': 'dynamic', 'workflowName': 'Dependabot Updates', 'conclusion': 'failure'},
      {'databaseId': 2, 'headSha': 'abc', 'event': 'push', 'workflowName': 'CI', 'conclusion': 'success'},
      {'databaseId': 1, 'headSha': 'old', 'event': 'push', 'workflowName': 'CI', 'conclusion': 'failure'},
    ];
    expect(CiService.ownRuns(runs).map((r) => r['databaseId']), [2, 1]);
  });

  test('repoDisplayName drops the UteamUP_ prefix only', () {
    expect(repoDisplayName('/x/UteamUP_Backend'), 'Backend');
    expect(repoDisplayName('/x/ActiveProjects/'), 'ActiveProjects');
  });
}
