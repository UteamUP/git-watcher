import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'process_env.dart';

enum CiState { none, queued, running, success, failure, cancelled }

/// GitHub Actions state for the newest commit on a branch, across all its workflow runs.
class CiStatus {
  const CiStatus({
    required this.state,
    this.doneJobs = 0,
    this.totalJobs = 0,
    this.failedJob,
    this.startedAt,
    this.finishedAt,
    this.url,
    this.runId,
    this.failedRuns = const [],
    this.expectedEnd,
  });

  static const none = CiStatus(state: CiState.none);

  /// The run to read logs from: the failed one, or the one still running.
  final int? runId;

  /// Every failed workflow run of the commit, so a fix sees all of them and not only the first.
  final List<int> failedRuns;
  final CiState state;
  final int doneJobs;
  final int totalJobs;
  final String? failedJob;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? url;

  /// When a running pipeline should finish, from how long its workflows took last time they passed.
  final DateTime? expectedEnd;

  bool get active => state == CiState.running || state == CiState.queued;

  Duration? get remaining {
    if (!active || expectedEnd == null) return null;
    final left = expectedEnd!.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// The further along of finished jobs and elapsed time, so the bar keeps moving during one long job.
  double get progress {
    final byJobs = totalJobs == 0 ? 0.0 : doneJobs / totalJobs;
    if (!active || startedAt == null || expectedEnd == null) return byJobs;
    final total = expectedEnd!.difference(startedAt!).inSeconds;
    if (total <= 0) return byJobs;
    final byTime = (DateTime.now().difference(startedAt!).inSeconds / total).clamp(0.0, .97);
    return byJobs > byTime ? byJobs : byTime;
  }

  Duration? get duration =>
      startedAt == null ? null : (finishedAt ?? DateTime.now()).difference(startedAt!);

  Map<String, Object?> toJson() => {
        'state': state.name,
        if (active) 'progress': (progress * 100).round(),
        if (remaining != null) 'secondsLeft': remaining!.inSeconds,
        if (totalJobs > 0) 'jobs': '$doneJobs/$totalJobs',
        if (failedJob != null) 'failedJob': failedJob,
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'url': url,
      };
}

class CiService {
  CiService(this.env) : gh = env.which('gh');

  final ProcessEnv env;
  final String? gh;
  final _failedJobs = <int, String?>{};

  Future<CiStatus> status(String repo, String branch) async {
    if (gh == null || branch.startsWith('HEAD')) return CiStatus.none;
    final listed = await _gh(repo, [
      'run', 'list', '--branch', branch, '--limit', '40', '--json',
      'databaseId,headSha,status,conclusion,createdAt,updatedAt,url,workflowName,event',
    ]);
    if (listed == null) return CiStatus.none;
    final runs = ownRuns((jsonDecode(listed) as List).cast<Map<String, dynamic>>());
    if (runs.isEmpty) return CiStatus.none;

    final sha = runs.first['headSha'];
    final group = runs.where((r) => r['headSha'] == sha).toList();
    final started = group.map((r) => DateTime.parse(r['createdAt'] as String)).reduce((a, b) => a.isBefore(b) ? a : b);
    final finished = group.map((r) => DateTime.parse(r['updatedAt'] as String)).reduce((a, b) => a.isAfter(b) ? a : b);
    final active = group.where((r) => r['status'] != 'completed').toList();

    if (active.isNotEmpty) {
      var done = 0;
      var total = 0;
      for (final run in group) {
        final jobs = await _jobs(repo, run['databaseId'] as int);
        total += jobs.length;
        done += jobs.where((j) => j['status'] == 'completed').length;
      }
      return CiStatus(
        state: done == 0 && active.every((r) => r['status'] != 'in_progress') ? CiState.queued : CiState.running,
        doneJobs: done,
        totalJobs: total,
        startedAt: started.toLocal(),
        url: active.first['url'] as String?,
        runId: active.first['databaseId'] as int?,
        expectedEnd: estimateEnd(active, runs)?.toLocal(),
      );
    }

    final failed = group.where((r) => const {'failure', 'timed_out', 'startup_failure'}.contains(r['conclusion'])).toList();
    if (failed.isNotEmpty) {
      final id = failed.first['databaseId'] as int;
      final job = _failedJobs.containsKey(id) ? _failedJobs[id] : _failedJobs[id] = await _firstFailedJob(repo, id);
      return CiStatus(
        state: CiState.failure,
        failedJob: job,
        startedAt: started.toLocal(),
        finishedAt: finished.toLocal(),
        url: failed.first['url'] as String?,
        runId: id,
        failedRuns: [for (final run in failed) run['databaseId'] as int],
      );
    }

    final cancelled = group.any((r) => r['conclusion'] == 'cancelled');
    return CiStatus(
      state: cancelled ? CiState.cancelled : CiState.success,
      startedAt: started.toLocal(),
      finishedAt: finished.toLocal(),
      url: group.first['url'] as String?,
    );
  }

  /// The latest expected finish among the active runs: each run's start plus the median of the last
  /// five successful runs of the same workflow on this branch. Null when there is no history yet.
  static DateTime? estimateEnd(List<Map<String, dynamic>> active, List<Map<String, dynamic>> history) {
    DateTime? latest;
    for (final run in active) {
      final past = history
          .where((r) => r['workflowName'] == run['workflowName'] && r['status'] == 'completed' && r['conclusion'] == 'success')
          .map((r) => DateTime.parse(r['updatedAt'] as String).difference(DateTime.parse(r['createdAt'] as String)))
          .where((d) => d > Duration.zero)
          .take(5)
          .toList()
        ..sort();
      if (past.isEmpty) continue;
      final end = DateTime.parse(run['createdAt'] as String).add(past[past.length ~/ 2]);
      if (latest == null || end.isAfter(latest)) latest = end;
    }
    return latest;
  }

  /// The output of the failed steps of a run, newest lines kept, for an AI agent to read.
  /// Runs the repository's own workflows started, newest first. GitHub's dynamic runs (Dependabot updates,
  /// default code scanning) are left out: they are not the project's pipeline and code cannot turn them green.
  static List<Map<String, dynamic>> ownRuns(List<Map<String, dynamic>> runs) =>
      runs.where((run) => run['event'] != 'dynamic').toList();

  /// The failed steps of each run, the newest lines of each when they are long.
  Future<String> failedLog(String repo, List<int> runIds, {int maxChars = 24000}) async {
    final share = maxChars ~/ runIds.length;
    final parts = <String>[];
    for (final runId in runIds) {
      final log = await _gh(repo, ['run', 'view', '$runId', '--log-failed']);
      if (log == null || log.trim().isEmpty) continue;
      final text = log.length > share ? '[log truncated]\n${log.substring(log.length - share)}' : log;
      parts.add(runIds.length == 1 ? text : '=== Workflow run $runId ===\n$text');
    }
    if (parts.isEmpty) throw StateError('Could not read the failed logs of runs ${runIds.join(', ')} (is gh signed in?)');
    return parts.join('\n\n');
  }

  Future<List<Map<String, dynamic>>> _jobs(String repo, int runId) async {
    final out = await _gh(repo, ['run', 'view', '$runId', '--json', 'jobs']);
    if (out == null) return const [];
    return ((jsonDecode(out) as Map<String, dynamic>)['jobs'] as List).cast<Map<String, dynamic>>();
  }

  Future<String?> _firstFailedJob(String repo, int runId) async {
    final jobs = await _jobs(repo, runId);
    for (final job in jobs) {
      if (job['conclusion'] == 'failure' || job['conclusion'] == 'timed_out') return job['name'] as String?;
    }
    return null;
  }

  Future<String?> _gh(String repo, List<String> args) async {
    try {
      final result = await Process.run(gh!, args, workingDirectory: repo, environment: env.environment)
          .timeout(const Duration(seconds: 25));
      return result.exitCode == 0 ? result.stdout as String : null;
    } on Object {
      return null;
    }
  }
}
