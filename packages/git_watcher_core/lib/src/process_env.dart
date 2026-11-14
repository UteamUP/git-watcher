import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Environment for child processes. Apps started from Finder get a bare PATH,
/// so git hooks, credential helpers and the claude CLI would not be found
/// without the PATH of the user's login shell.
class ProcessEnv {
  ProcessEnv(this.environment);

  final Map<String, String> environment;

  String get home =>
      environment['HOME'] ??
      environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      (Platform.isWindows ? r'C:\' : '/');

  static Future<ProcessEnv> resolve() async {
    final env = Map<String, String>.of(Platform.environment);
    if (Platform.isWindows) {
      final home = env['USERPROFILE'] ?? env['HOME'] ?? '';
      final localAppData = env['LOCALAPPDATA'] ?? '';
      final programFiles = env['ProgramFiles'] ?? r'C:\Program Files';
      final appData = env['APPDATA'] ?? '';
      final existingPath = env.entries
          .where((e) => e.key.toUpperCase() == 'PATH')
          .map((e) => e.value)
          .join(';');
      env.removeWhere((k, _) => k.toUpperCase() == 'PATH');
      final dirs = <String>[
        ...existingPath.split(';'),
        if (home.isNotEmpty) '$home\\.local\\bin',
        if (home.isNotEmpty) '$home\\go\\bin',
        if (localAppData.isNotEmpty) '$localAppData\\Microsoft\\WinGet\\Links',
        if (appData.isNotEmpty) '$appData\\npm',
        '$programFiles\\nodejs',
        '$programFiles\\Go\\bin',
        '$programFiles\\GitHub CLI',
        if (localAppData.isNotEmpty) '$localAppData\\Programs\\Git\\cmd',
        '$programFiles\\Git\\cmd',
      ];
      env['PATH'] = dirs.where((d) => d.isNotEmpty).toSet().join(';');
      env['GIT_TERMINAL_PROMPT'] = '0';
      env['GIT_OPTIONAL_LOCKS'] = '0';
      env['GIT_EDITOR'] = 'true';
      env.putIfAbsent('LANG', () => 'en_US.UTF-8');
      return ProcessEnv(env);
    }
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
    final sep = Platform.isWindows ? ';' : ':';
    final pathValue = environment['PATH'] ?? environment['Path'] ?? '';
    final suffixes = Platform.isWindows ? const ['', '.exe', '.cmd', '.bat'] : const [''];
    for (final dir in pathValue.split(sep)) {
      if (dir.isEmpty) continue;
      for (final suffix in suffixes) {
        final candidate = '$dir${Platform.pathSeparator}$executable$suffix';
        if (File(candidate).existsSync()) return candidate;
      }
    }
    return null;
  }
}
