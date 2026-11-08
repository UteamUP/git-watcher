import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'process_env.dart';

class GitException implements Exception {
  const GitException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GitResult {
  const GitResult(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get ok => exitCode == 0;

  /// Git writes progress and hook output to stderr, so both streams matter to the user.
  String get combined => [stdout.trim(), stderr.trim()].where((s) => s.isNotEmpty).join('\n');
}

class Git {
  Git(this.env) : executable = env.which('git') ?? '/usr/bin/git';

  final ProcessEnv env;
  final String executable;

  Future<GitResult> run(
    String repo,
    List<String> args, {
    String? stdin,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final process = await Process.start(
      executable,
      ['--literal-pathspecs', '-c', 'core.quotepath=false', '-c', 'color.ui=false', ...args],
      workingDirectory: repo,
      environment: env.environment,
    );
    if (stdin != null) process.stdin.add(utf8.encode(stdin));
    unawaited(process.stdin.close());

    final stdout = process.stdout.transform(const Utf8Decoder(allowMalformed: true)).join();
    final stderr = process.stderr.transform(const Utf8Decoder(allowMalformed: true)).join();
    final exitCode = await process.exitCode.timeout(timeout, onTimeout: () {
      process.kill();
      return -1;
    });
    final result = GitResult(exitCode, await stdout, await stderr);
    if (exitCode == -1) {
      throw GitException('git ${args.first} timed out after ${timeout.inMinutes} min');
    }
    return result;
  }

  /// Runs git and throws [GitException] with git's own output when it fails.
  Future<GitResult> check(
    String repo,
    List<String> args, {
    String? stdin,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final result = await run(repo, args, stdin: stdin, timeout: timeout);
    if (!result.ok) {
      final message = result.combined;
      throw GitException(message.isEmpty ? 'git ${args.first} failed (${result.exitCode})' : message);
    }
    return result;
  }
}
