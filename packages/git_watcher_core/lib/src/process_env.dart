import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Environment for child processes. Apps started from Finder get a bare PATH,
/// so git hooks, credential helpers and the claude CLI would not be found
/// without the PATH of the user's login shell.
class ProcessEnv {
  ProcessEnv(this.environment);

  final Map<String, String> environment;

  String get home => environment['HOME'] ?? Platform.environment['HOME'] ?? '/';

  static Future<ProcessEnv> resolve() async {
    final env = Map<String, String>.of(Platform.environment);
    final home = env['HOME'] ?? '';
    final shellPath = await _loginShellPath(env['SHELL'] ?? '/bin/zsh');
    final dirs = <String>[
      ...?shellPath?.split(':'),
      ...?env['PATH']?.split(':'),
      '/opt/homebrew/bin',
      '/usr/local/bin',
      '$home/.local/bin',
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin',
    ];
    env['PATH'] = dirs.where((d) => d.isNotEmpty).toSet().join(':');
    env['GIT_TERMINAL_PROMPT'] = '0';
    env['GIT_OPTIONAL_LOCKS'] = '0';
    env['GIT_EDITOR'] = 'true';
    env.putIfAbsent('LANG', () => 'en_US.UTF-8');
    return ProcessEnv(env);
  }

  static Future<String?> _loginShellPath(String shell) async {
    Process? process;
    try {
      process = await Process.start(shell, ['-l', '-i', '-c', r'printf "__GW__%s__GW__" "$PATH"']);
      unawaited(process.stdin.close());
      final output = process.stdout.transform(const Utf8Decoder(allowMalformed: true)).join();
      unawaited(process.stderr.drain<void>());
      final text = await output.timeout(const Duration(seconds: 4));
      return RegExp(r'__GW__(.*)__GW__').firstMatch(text)?.group(1);
    } on Object {
      return null;
    } finally {
      process?.kill();
    }
  }

  String? which(String executable) {
    for (final dir in (environment['PATH'] ?? '').split(':')) {
      if (dir.isEmpty) continue;
      final candidate = '$dir/$executable';
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }
}
