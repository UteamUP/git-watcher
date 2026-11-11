import 'dart:io';

import 'package:git_watcher_core/git_watcher_core.dart';
import 'package:test/test.dart';

/// Runs against real git in a throwaway folder under the system temp directory.
void main() {
  late Directory root;
  late String repo;
  late GitWatcherService service;

  Future<void> git(List<String> args, {String? cwd}) async {
    final result = await Process.run('git', args, workingDirectory: cwd ?? repo);
    if (result.exitCode != 0) fail('git ${args.join(' ')}: ${result.stderr}');
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('git_watcher_test_');
    repo = '${root.path}/UteamUP_Sample';
    await Directory(repo).create();
    await git(['init', '-q', '-b', 'main']);
    await git(['config', 'user.email', 'test@example.com']);
    await git(['config', 'user.name', 'Test']);
    await File('$repo/a.txt').writeAsString('one\n');
    await File('$repo/b.txt').writeAsString('two\n');
    await git(['add', '.']);
    await git(['commit', '-q', '-m', 'chore: start']);
    service = GitWatcherService(Git(await ProcessEnv.resolve()));
  });

  tearDown(() => root.delete(recursive: true));

  test('status counts modified, untracked and deleted files with line stats', () async {
    await File('$repo/a.txt').writeAsString('one\nmore\n');
    await File('$repo/new file.txt').writeAsString('x\ny\nz\n');
    await File('$repo/b.txt').delete();

    final status = await service.status(repo);
    expect(status.branch, 'main');
    expect(status.lastCommitSubject, 'chore: start');
    expect(status.count(ChangeKind.modified), 1);
    expect(status.count(ChangeKind.untracked), 1);
    expect(status.count(ChangeKind.deleted), 1);

    final stats = await service.lineStats(repo, status);
    expect(stats['a.txt']!.added, 1);
    expect(stats['new file.txt']!.added, 3);
    expect(stats['b.txt']!.deleted, 1);
  });

  test('commit takes only the chosen files and leaves other staged work alone', () async {
    await File('$repo/a.txt').writeAsString('changed\n');
    await File('$repo/b.txt').writeAsString('also changed\n');
    await git(['add', 'b.txt']);
    await File('$repo/c*.txt').writeAsString('glob-looking name\n');

    final status = await service.status(repo);
    final chosen = status.files.where((f) => f.path == 'a.txt' || f.path == 'c*.txt').toList();
    await service.commit(repo, chosen, 'feat: pick two files');

    final after = await service.status(repo);
    expect(after.files.map((f) => f.path), ['b.txt']);
    expect(after.files.single.staged, isTrue);
    final log = await service.log(repo, limit: 1);
    expect(log.single.subject, 'feat: pick two files');
    expect(await service.commitFiles(repo, log.single.hash), hasLength(2));
  });

  test('commit refuses an empty message or no files', () async {
    await File('$repo/a.txt').writeAsString('changed\n');
    final files = (await service.status(repo)).files;
    expect(() => service.commit(repo, files, '  '), throwsA(isA<GitException>()));
    expect(() => service.commit(repo, const [], 'feat: x'), throwsA(isA<GitException>()));
  });

  test('commit includes staged deletions together with modified and untracked files', () async {
    await git(['rm', 'a.txt']);
    await File('$repo/b.txt').writeAsString('changed\n');
    await File('$repo/new [draft] *.txt').writeAsString('new\n');

    await service.commit(repo, (await service.status(repo)).files, 'feat: commit all changes');

    expect((await service.status(repo)).isClean, isTrue);
    final log = await service.log(repo, limit: 1);
    final files = await service.commitFiles(repo, log.single.hash);
    expect({for (final file in files) file.path: file.kind}, {
      'a.txt': ChangeKind.deleted,
      'b.txt': ChangeKind.modified,
      'new [draft] *.txt': ChangeKind.added,
    });
  });

  for (final staged in [false, true]) {
    test('commit handles a ${staged ? 'staged' : 'working-tree'} deletion without committing other staged files', () async {
      if (staged) {
        await git(['rm', 'a.txt']);
      } else {
        await File('$repo/a.txt').delete();
      }
      await File('$repo/b.txt').writeAsString('unrelated staged work\n');
      await git(['add', 'b.txt']);

      final chosen = (await service.status(repo)).files.where((file) => file.path == 'a.txt').toList();
      await service.commit(repo, chosen, 'fix: remove selected file');

      final after = await service.status(repo);
      expect(after.files.single.path, 'b.txt');
      expect(after.files.single.staged, isTrue);
      final log = await service.log(repo, limit: 1);
      final files = await service.commitFiles(repo, log.single.hash);
      expect(files.single.path, 'a.txt');
      expect(files.single.kind, ChangeKind.deleted);
    });
  }

  for (final editAfterRename in [false, true]) {
    test('commit handles a staged rename${editAfterRename ? ' with additional working-tree edits' : ''}', () async {
      const renamed = 'renamed [draft].txt';
      await git(['mv', 'a.txt', renamed]);
      if (editAfterRename) await File('$repo/$renamed').writeAsString('one\n\n');
      await File('$repo/b.txt').writeAsString('unrelated staged work\n');
      await git(['add', 'b.txt']);

      final chosen = (await service.status(repo)).files.where((file) => file.path == renamed).toList();
      expect(chosen.single.originalPath, 'a.txt');
      await service.commit(repo, chosen, 'refactor: rename selected file');

      final after = await service.status(repo);
      expect(after.files.single.path, 'b.txt');
      expect(after.files.single.staged, isTrue);
      final log = await service.log(repo, limit: 1);
      final files = await service.commitFiles(repo, log.single.hash);
      expect(files.single.path, renamed);
      expect(files.single.originalPath, 'a.txt');
      final content = await Process.run('git', ['show', 'HEAD:$renamed'], workingDirectory: repo);
      expect(content.exitCode, 0);
      expect(content.stdout, editAfterRename ? 'one\n\n' : 'one\n');
    });
  }

  test('working diff of a tracked file and an untracked file', () async {
    await File('$repo/a.txt').writeAsString('one\ntwo\n');
    await File('$repo/fresh.txt').writeAsString('hello\n');
    final status = await service.status(repo);
    final tracked = await service.workingDiff(repo, status.files.firstWhere((f) => f.path == 'a.txt'), hasCommits: true);
    expect(tracked.additions, 1);
    final untracked = await service.workingDiff(repo, status.files.firstWhere((f) => f.path == 'fresh.txt'), hasCommits: true);
    expect(untracked.lines.last.text, 'hello');
    expect(untracked.additions, 1);
  });

  test('discovery finds the root repo and nested repos but skips node_modules', () async {
    await git(['init', '-q'], cwd: root.path);
    await Directory('${root.path}/group/inner').create(recursive: true);
    await git(['init', '-q'], cwd: '${root.path}/group/inner');
    await Directory('${root.path}/node_modules/pkg').create(recursive: true);
    await git(['init', '-q'], cwd: '${root.path}/node_modules/pkg');

    final all = await GitWatcherService.discoverRepos(root.path);
    expect(all.first, root.path);
    expect(all, containsAll([repo, '${root.path}/group/inner']));
    expect(all.any((p) => p.contains('node_modules')), isFalse);

    final shallow = await GitWatcherService.discoverRepos(root.path, recursive: false);
    expect(shallow, isNot(contains('${root.path}/group/inner')));
    expect(shallow, contains(repo));
  });

  test('push without a remote fails with a clear message', () async {
    expect(() => service.push(repo), throwsA(isA<GitException>().having((e) => e.message, 'message', contains('no remote'))));
  });
}
