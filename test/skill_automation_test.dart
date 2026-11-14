import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:git_watcher/state/ai_helper.dart';
import 'package:git_watcher/state/watcher_controller.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

const _repoPath = '/sample';
final _env = ProcessEnv({'HOME': '/', 'PATH': ''});

void main() {
  late RepoAutomationConfig automation;
  late _MemoryConfig config;
  late _Repository service;
  late _Watcher watcher;
  late RepoState repo;

  setUp(() {
    automation = RepoAutomationConfig(
      watchCommitsForSkills: true,
      skills: [SkillStepConfig(skill: 'uteamup-mobilerelease')],
      lastSkillCommit: 'head',
      lastSkillFingerprint: 'before',
    );
    config = _MemoryConfig(automation);
    service = _Repository();
    watcher = _Watcher(service, config);
    repo = RepoState(_repoPath, null);
    addTearDown(watcher.dispose);
  });

  test('unchanged repositories never launch skills, including repeated Run now clicks', () async {
    expect(await watcher.runRepoSkillsNow(repo), isFalse);
    expect(await watcher.runRepoSkillsNow(repo), isFalse);
    expect(watcher.helper.calls, 0);
  });

  test(
    'a changed push or file fingerprint runs once without a new HEAD',
    () async {
      service.fingerprint = 'changed';
      expect(await watcher.runRepoSkillsNow(repo), isTrue);
      expect(automation.lastSkillFingerprint, 'changed');
      expect(await watcher.runRepoSkillsNow(repo), isFalse);
      expect(watcher.helper.calls, 1);
    },
  );

  test('legacy commit baselines preserve pending new commits', () async {
    automation.lastSkillFingerprint = null;
    service.head = 'new-head';
    expect(await watcher.runRepoSkillsNow(repo), isTrue);
    expect(automation.lastSkillCommit, 'new-head');
    expect(watcher.helper.calls, 1);
  });

  test('legacy unchanged commits establish a fingerprint without launching a release', () async {
    automation.lastSkillFingerprint = null;
    expect(await watcher.runRepoSkillsNow(repo), isFalse);
    expect(automation.lastSkillFingerprint, 'before');
    service.fingerprint = 'new-files';
    expect(await watcher.runRepoSkillsNow(repo), isTrue);
    expect(watcher.helper.calls, 1);
  });

  test('repositories without a previous baseline are observed before skills can run', () async {
    automation
      ..lastSkillCommit = null
      ..lastSkillFingerprint = null;
    expect(await watcher.runRepoSkillsNow(repo), isFalse);
    expect(automation.lastSkillCommit, 'head');
    expect(automation.lastSkillFingerprint, 'before');
    expect(watcher.helper.calls, 0);
  });

  test('skill-authored changes are persisted and do not cause a loop or a restart rerun', () async {
    service.fingerprint = 'new-files';
    watcher.helper.onRun = () {
      service
        ..head = 'release-commit'
        ..fingerprint = 'after-release';
    };
    expect(await watcher.runRepoSkillsNow(repo), isTrue);
    expect(automation.lastSkillCommit, 'release-commit');
    expect(automation.lastSkillFingerprint, 'after-release');
    expect(await watcher.runRepoSkillsNow(repo), isFalse);
    expect(watcher.helper.calls, 1);

    final restored = RepoAutomationConfig.fromJson(automation.toJson());
    final restarted = _Watcher(service, _MemoryConfig(restored));
    addTearDown(restarted.dispose);
    expect(await restarted.runRepoSkillsNow(repo), isFalse);
    expect(restarted.helper.calls, 0);
  });

  test(
    'failed skill attempts are not retried without a repository change',
    () async {
      service.fingerprint = 'new-files';
      watcher.helper.succeeds = false;
      expect(await watcher.runRepoSkillsNow(repo), isFalse);
      expect(await watcher.runRepoSkillsNow(repo), isFalse);
      expect(watcher.helper.calls, 1);
    },
  );

  test('unreadable repository state cannot start a skill', () async {
    service.failFingerprint = true;
    expect(await watcher.runRepoSkillsNow(repo), isFalse);
    expect(repo.error, isNotNull);
    expect(watcher.helper.calls, 0);
  });

  test(
    'concurrent Run now requests cannot launch the same skills twice',
    () async {
      service.fingerprint = 'new-files';
      watcher.helper.pending = Completer<void>();
      final first = watcher.runRepoSkillsNow(repo);
      await watcher.helper.started.future;
      expect(await watcher.runRepoSkillsNow(repo), isFalse);
      watcher.helper.pending!.complete();
      expect(await first, isTrue);
      expect(watcher.helper.calls, 1);
    },
  );
}

class _MemoryConfig extends WatcherConfig {
  _MemoryConfig(RepoAutomationConfig automation)
    : super(root: '/', repoAutomation: {_repoPath: automation});

  @override
  void save() {}
}

class _Repository extends GitWatcherService {
  _Repository() : super(Git(_env));

  String head = 'head';
  String fingerprint = 'before';
  bool failFingerprint = false;

  @override
  Future<RepoStatus> status(String repo) async => RepoStatus(
    branch: 'main',
    upstream: 'origin/main',
    ahead: 0,
    behind: 0,
    hasCommits: true,
    files: const [],
    headHash: head,
  );

  @override
  Future<String> changeFingerprint(String repo, RepoStatus status) async {
    if (failFingerprint) {
      throw const GitException('Could not read repository state');
    }
    return fingerprint;
  }
}

class _Watcher extends WatcherController {
  _Watcher(_Repository service, _MemoryConfig config)
    : _repository = service,
      super(
        env: _env,
        config: config,
        locale: ValueNotifier(const Locale('en')),
      );

  final _Repository _repository;
  late final _Helper _helper = _Helper(this);

  @override
  _Repository get service => _repository;

  @override
  _Helper get helper => _helper;
}

class _Helper extends AiHelper {
  _Helper(super.watcher);

  int calls = 0;
  bool succeeds = true;
  void Function()? onRun;
  Completer<void>? pending;
  final started = Completer<void>();

  @override
  Future<bool> runSkills(RepoState repo, List<SkillStepConfig> skills) async {
    calls++;
    running = true;
    try {
      onRun?.call();
      if (!started.isCompleted) started.complete();
      await pending?.future;
      return succeeds;
    } finally {
      running = false;
    }
  }
}
