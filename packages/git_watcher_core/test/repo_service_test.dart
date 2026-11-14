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

  Future<String> fingerprint() async =>
      service.changeFingerprint(repo, await service.status(repo));

  test('change fingerprints stay stable across polls, timestamp changes and ignored files', () async {
    final before = await fingerprint();
    await File('$repo/a.txt').setLastModified(DateTime(2025));
    await File('$repo/.git/info/exclude')
        .writeAsString('ignored.bin\n', mode: FileMode.append);
    await File('$repo/ignored.bin').writeAsBytes([0, 1, 2]);
    expect(await fingerprint(), before);
    expect(await fingerprint(), before);
  });

  test(
    'change fingerprints detect same-size edits to an already dirty file',
    () async {
      final file = File('$repo/a.txt');
      await file.writeAsString('alpha\n');
      final timestamp = await file.lastModified();
      final before = await fingerprint();
      await file.writeAsString('bravo\n');
      await file.setLastModified(timestamp);
      expect(await fingerprint(), isNot(before));
    },
  );

  test('change fingerprints include untracked binary contents', () async {
    final file = File('$repo/new file.bin');
    await file.writeAsBytes([0, 1, 2]);
    final before = await fingerprint();
    await file.writeAsBytes([0, 2, 2]);
    expect(await fingerprint(), isNot(before));
  });

  test(
    'change fingerprints support unusual paths',
    () async {
      final file = File('$repo/new [draft] *\nfile.bin');
      await file.writeAsBytes([0, 1, 2]);
      final before = await fingerprint();
      await file.writeAsBytes([0, 2, 2]);
      expect(await fingerprint(), isNot(before));
    },
    skip: Platform.isWindows,
  );

  test('change fingerprints detect staged content changes with an identical working tree', () async {
    final file = File('$repo/a.txt');
    await file.writeAsString('staged one\n');
    await git(['add', 'a.txt']);
    await file.writeAsString('working tree\n');
    final before = await fingerprint();
    await file.writeAsString('staged two\n');
    await git(['add', 'a.txt']);
    await file.writeAsString('working tree\n');
    expect(await fingerprint(), isNot(before));
  });

  test('change fingerprints detect pushes without changing HEAD and ignore repeated pushes', () async {
    final remote = '${root.path}/origin.git';
    await git(['init', '--bare', '-q', remote], cwd: root.path);
    await git(['remote', 'add', 'origin', remote]);
    await git(['push', '-u', 'origin', 'main']);
    await git(['commit', '--allow-empty', '-q', '-m', 'chore: pending push']);
    final head = (await service.status(repo)).headHash;
    final before = await fingerprint();
    await git(['push']);
    final pushed = await fingerprint();
    expect((await service.status(repo)).headHash, head);
    expect(pushed, isNot(before));
    await git(['push']);
    expect(await fingerprint(), pushed);
  });

  test('change fingerprints support repositories without commits', () async {
    repo = '${root.path}/empty';
    await Directory(repo).create();
    await git(['init', '-q', '-b', 'main']);
    final before = await fingerprint();
    await File('$repo/first.txt').writeAsString('first\n');
    expect(await fingerprint(), isNot(before));
  });

  test(
    'change fingerprints hash symlink targets without following them',
    () async {
      final link = Link('$repo/link');
      await link.create('missing-one');
      final before = await fingerprint();
      await link.delete();
      await link.create('missing-two');
      expect(await fingerprint(), isNot(before));
    },
    skip: Platform.isWindows,
  );

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
    expect((await service.status(repo)).remoteUrl, isNull);
    expect(() => service.push(repo), throwsA(isA<GitException>().having((e) => e.message, 'message', contains('no remote'))));
  });

  test('status reads the git remote URL from origin and exposes headHash', () async {
    await git(['remote', 'add', 'origin', 'https://github.com/UteamUP/UteamUP_Sample.git']);
    final status = await service.status(repo);
    expect(status.remoteUrl, 'https://github.com/UteamUP/UteamUP_Sample.git');
    expect(status.headHash, isNotNull);
    expect(status.headHash!.length, 40);
  });

  test('RepoAutomationConfig round-trips independent commit/push flags and skill steps', () {
    final original = RepoAutomationConfig(
      autoCommit: true,
      autoPush: false,
      syncIntervalMinutes: 10,
      pushIntervalMinutes: 25,
      watchCommitsForSkills: true,
      skillIntervalMinutes: 30,
      lastSkillCommit: 'abc1234567890',
      skills: [
        SkillStepConfig(skill: 'uteamup-mobilerelease', agent: AgentProvider.claudeCode, model: 'opus'),
        SkillStepConfig(skill: 'uteamup-cli', agent: AgentProvider.codex, model: 'gpt-5.4', enabled: false),
      ],
    );
    final decoded = RepoAutomationConfig.fromJson(original.toJson().cast<String, dynamic>());
    expect(decoded.autoCommit, isTrue);
    expect(decoded.autoPush, isFalse);
    expect(decoded.syncIntervalMinutes, 10);
    expect(decoded.pushIntervalMinutes, 25);
    final legacyDecoded = RepoAutomationConfig.fromJson({'autoCommit': true, 'autoPush': true, 'syncIntervalMinutes': 12});
    expect(legacyDecoded.pushIntervalMinutes, 12);
    expect(decoded.watchCommitsForSkills, isTrue);
    expect(decoded.skillIntervalMinutes, 30);
    expect(decoded.lastSkillCommit, 'abc1234567890');
    expect(decoded.skills, hasLength(2));
    expect(decoded.skills[0].skill, 'uteamup-mobilerelease');
    expect(decoded.skills[0].agent, AgentProvider.claudeCode);
    expect(decoded.skills[0].model, 'opus');
    expect(decoded.skills[0].enabled, isTrue);
    expect(decoded.skills[1].skill, 'uteamup-cli');
    expect(decoded.skills[1].agent, AgentProvider.codex);
    expect(decoded.skills[1].model, 'gpt-5.4');
    expect(decoded.skills[1].enabled, isFalse);
  });

  test('AiService discovers skills and resolves SKILL.md across root and repo folders', () async {
    final skillDir = Directory('${root.path}/.agent/skills/sample-release');
    await skillDir.create(recursive: true);
    final skillFile = File('${skillDir.path}/SKILL.md');
    await skillFile.writeAsString('---\nname: sample-release\n---\n');

    final env = ProcessEnv({'HOME': root.path, 'USERPROFILE': root.path, 'PATH': ''});
    final ai = AiService(env);
    final discovered = ai.discoverSkills(root: root.path, repo: repo);
    expect(discovered, contains('sample-release'));
    expect(ai.resolveSkillFile('sample-release', root: root.path, repo: repo), isNotNull);
    expect(ai.resolveSkillFile('sample-release upgrade', root: root.path, repo: repo), isNotNull);
    expect(ai.resolveSkillFile('/sample-release --dry-run', root: root.path, repo: repo), isNotNull);
    final parsed = AiService.parseSkillSpec('/uteamup-cli upgrade');
    expect(parsed.name, 'uteamup-cli');
    expect(parsed.args, 'upgrade');
  });
}
