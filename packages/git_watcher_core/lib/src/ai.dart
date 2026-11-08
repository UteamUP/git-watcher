import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'git.dart';
import 'process_env.dart';

/// Where commit messages come from: a local CLI on the user's subscription, or an API key.
enum AiProvider {
  claudeCode(cli: true),
  codex(cli: true),
  anthropic(defaultModel: 'claude-opus-5-5', defaultBaseUrl: 'https://api.anthropic.com'),
  openai(defaultModel: 'gpt-5-mini', defaultBaseUrl: 'https://api.openai.com/v1'),
  deepseek(defaultModel: 'deepseek-chat', defaultBaseUrl: 'https://api.deepseek.com'),
  gemini(defaultModel: 'gemini-2.5-flash', defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai'),
  custom(defaultModel: '', defaultBaseUrl: 'https://openrouter.ai/api/v1');

  const AiProvider({this.cli = false, this.defaultModel = '', this.defaultBaseUrl = ''});

  final bool cli;
  final String defaultModel;
  final String defaultBaseUrl;

  bool get needsKey => !cli;

  static AiProvider? byName(String? name) => AiProvider.values.where((p) => p.name == name).firstOrNull;
}

/// Agents that can run git themselves to fix a failed commit, rebase or push.
enum AgentProvider {
  claudeCode,
  codex,
  off;

  static AgentProvider? byName(String? name) => AgentProvider.values.where((p) => p.name == name).firstOrNull;
}

class AiSettings {
  const AiSettings({required this.provider, required this.model, required this.baseUrl});

  final AiProvider provider;
  final String model;
  final String baseUrl;
}

/// One line of progress from an agent run.
class AgentEvent {
  const AgentEvent(this.text, {this.done = false, this.failed = false});

  final String text;
  final bool done;
  final bool failed;
}

/// API keys live in the macOS login keychain, never in a file.
class KeyStore {
  static const _service = 'GIT Watcher AI';
  static const _security = '/usr/bin/security';

  static Future<String?> read(AiProvider provider) async {
    final result = await Process.run(_security, ['find-generic-password', '-s', _service, '-a', provider.name, '-w']);
    final key = (result.stdout as String).trim();
    return result.exitCode == 0 && key.isNotEmpty ? key : null;
  }

  /// The key goes through stdin of `security -i`, so it never shows up in the process list.
  static Future<void> write(AiProvider provider, String key) async {
    final value = key.trim();
    if (value.isEmpty || RegExp(r'[\s"\\]').hasMatch(value)) {
      throw const GitException('Lykillinn má ekki vera tómur eða innihalda bil, gæsalappir eða bakstrik');
    }
    final process = await Process.start(_security, ['-i']);
    process.stdin.writeln('add-generic-password -U -s "$_service" -a "${provider.name}" -w "$value"');
    await process.stdin.close();
    final err = await process.stderr.transform(utf8.decoder).join();
    if (await process.exitCode != 0 || err.trim().isNotEmpty) {
      throw GitException('Gat ekki vistað lykilinn í Keychain: ${err.trim()}');
    }
  }

  static Future<void> delete(AiProvider provider) =>
      Process.run(_security, ['delete-generic-password', '-s', _service, '-a', provider.name]);
}

class AiService {
  AiService(this.env)
      : claude = env.which('claude'),
        codex = env.which('codex');

  final ProcessEnv env;
  final String? claude;
  final String? codex;

  /// Environment without the variables that make Claude Code think it is nested in another session.
  Map<String, String> get _environment => Map.of(env.environment)
    ..remove('CLAUDECODE')
    ..remove('CLAUDE_CODE_ENTRYPOINT')
    ..remove('CLAUDE_CODE_SSE_PORT');

  Future<bool> claudeLoggedIn() async {
    if (claude == null) return false;
    try {
      final result = await Process.run(claude!, ['auth', 'status'], environment: _environment).timeout(const Duration(seconds: 20));
      return (jsonDecode(result.stdout as String) as Map)['loggedIn'] == true;
    } on Object {
      return false;
    }
  }

  Future<bool> codexLoggedIn() async {
    if (codex == null) return false;
    try {
      final result = await Process.run(codex!, ['login', 'status'], environment: _environment).timeout(const Duration(seconds: 20));
      return result.exitCode == 0 && '${result.stdout}${result.stderr}'.contains('Logged in');
    } on Object {
      return false;
    }
  }

  Future<String> commitMessage({
    required AiSettings settings,
    required String repoName,
    required String changes,
    required List<String> recentSubjects,
    bool subjectOnly = false,
  }) async {
    final rules = _rules(subjectOnly);
    final request = 'Repository: $repoName\nRecent commit subjects (match their style):\n'
        '${recentSubjects.take(12).map((s) => '- $s').join('\n')}\n\nChanges:\n$changes';
    final raw = switch (settings.provider) {
      AiProvider.claudeCode => await _claudeCli(rules, request),
      AiProvider.codex => await _codexCli(rules, request),
      AiProvider.anthropic => await _anthropic(settings, rules, request),
      _ => await _openAiCompatible(settings, rules, request),
    };
    final message = raw.replaceAll(RegExp(r'^```[a-z]*\s*|```\s*$', multiLine: true), '').replaceAll('`', '').trim();
    if (message.isEmpty) throw const GitException('AI skilaði tómum skilaboðum');
    return subjectOnly ? message.split('\n').first.trim() : message;
  }

  static String _rules(bool subjectOnly) => '''
You write git commit messages.
- Conventional Commits: type(scope): subject. Types: feat, fix, chore, refactor, docs, test, perf, ci, style, build, remove.
- English, imperative mood, lowercase after the colon, no trailing period, at most 72 characters.
${subjectOnly ? '- Write only the subject line.' : '- Add a blank line and a short body (2-5 lines, each at most 100 characters) only when the change needs explaining.'}
- Never use backticks.
Reply with the commit message only, nothing else.''';

  Future<String> _claudeCli(String rules, String request) async {
    if (claude == null) throw const GitException('Claude Code (claude) fannst ekki á þessari vél');
    // --strict-mcp-config with no config: skip the user's MCP servers, which only slow a one-shot answer down.
    final out = await _run(
        claude!, ['-p', rules, '--model', 'haiku', '--no-session-persistence', '--strict-mcp-config', '--output-format', 'text'], request);
    if (out.contains('Failed to authenticate') || out.contains('Invalid API key') || out.contains('/login')) {
      throw const GitException('Claude Code er ekki innskráð. Opnaðu Stillingar og smelltu á Skrá inn, eða veldu annað AI.');
    }
    return out;
  }

  Future<String> _codexCli(String rules, String request) async {
    if (codex == null) throw const GitException('Codex (codex) fannst ekki á þessari vél');
    // Without MCP servers Codex exits as soon as it has answered; with them it can sit open for minutes.
    return _run(
      codex!,
      [
        'exec', '--skip-git-repo-check', '--sandbox', 'read-only', '--ephemeral', '--color', 'never',
        '-c', 'mcp_servers={}',
        '-c', 'model_reasoning_effort="low"',
        rules,
      ],
      request,
    );
  }

  /// One line per AI call in ~/.uteamup/gitwatcher-ai.log: tool, time, exit code. Never keys or diffs.
  void _log(String line) {
    try {
      final file = File('${env.home}/.uteamup/gitwatcher-ai.log');
      file.parent.createSync(recursive: true);
      if (file.existsSync() && file.lengthSync() > 1024 * 1024) file.writeAsStringSync('');
      file.writeAsStringSync('${DateTime.now().toIso8601String()} $line\n', mode: FileMode.append);
    } on FileSystemException {
      // Logging must never break an AI call.
    }
  }

  Future<String> _run(String executable, List<String> args, String stdin) async {
    final watch = Stopwatch()..start();
    final process = await Process.start(executable, args, workingDirectory: Directory.systemTemp.path, environment: _environment);
    process.stdin.add(utf8.encode(stdin));
    unawaited(process.stdin.close());
    final out = process.stdout.transform(const Utf8Decoder(allowMalformed: true)).join();
    final err = process.stderr.transform(const Utf8Decoder(allowMalformed: true)).join();
    final code = await process.exitCode.timeout(const Duration(minutes: 3), onTimeout: () {
      process.kill();
      return -1;
    });
    final stdout = (await out).trim();
    final stderr = (await err).trim();
    _log('${executable.split('/').last} message exit=$code ${watch.elapsed.inSeconds}s '
        '${code == 0 ? '' : stderr.split('\n').where((l) => l.trim().isNotEmpty).lastOrNull ?? ''}');
    if (code != 0) {
      if (code == -1) throw GitException('${executable.split('/').last} svaraði ekki innan 3 mínútna');
      final detail = [stderr, stdout].firstWhere((s) => s.isNotEmpty, orElse: () => 'exit $code');
      throw GitException('AI gat ekki skrifað skilaboð: ${detail.split('\n').last}');
    }
    return stdout;
  }

  Future<String> _anthropic(AiSettings settings, String rules, String request) async {
    final key = await _key(settings.provider);
    final model = settings.model.isEmpty ? settings.provider.defaultModel : settings.model;
    // Server-side fallback only exists for these models; it reroutes a policy decline instead of failing.
    final fallback = const {'claude-opus-5-5', 'claude-opus-5', 'claude-fable-5-1', 'claude-sonnet-5-5'}.contains(model);
    final json = await _post(
      Uri.parse('${_base(settings)}/v1/messages'),
      {
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
        if (fallback) 'anthropic-beta': 'server-side-fallback-2026-07-01',
      },
      {
        'model': model,
        'max_tokens': 4000,
        'system': rules,
        'output_config': {'effort': 'low'},
        if (fallback) 'fallbacks': 'default',
        'messages': [
          {'role': 'user', 'content': request},
        ],
      },
    );
    if (json['stop_reason'] == 'refusal') throw const GitException('Claude neitaði að skrifa þessi skilaboð');
    return [
      for (final block in (json['content'] as List? ?? const []).cast<Map<String, dynamic>>())
        if (block['type'] == 'text') block['text'] as String,
    ].join();
  }

  Future<String> _openAiCompatible(AiSettings settings, String rules, String request) async {
    final key = await _key(settings.provider);
    final model = settings.model.isEmpty ? settings.provider.defaultModel : settings.model;
    if (model.isEmpty) throw const GitException('Veldu módel í Stillingum');
    final json = await _post(
      Uri.parse('${_base(settings)}/chat/completions'),
      {'authorization': 'Bearer $key'},
      {
        'model': model,
        'messages': [
          {'role': 'system', 'content': rules},
          {'role': 'user', 'content': request},
        ],
      },
    );
    final choices = json['choices'] as List? ?? const [];
    if (choices.isEmpty) throw const GitException('AI skilaði engu svari');
    return ((choices.first as Map)['message'] as Map)['content'] as String? ?? '';
  }

  static String _base(AiSettings settings) {
    final base = settings.baseUrl.isEmpty ? settings.provider.defaultBaseUrl : settings.baseUrl;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  static Future<String> _key(AiProvider provider) async =>
      await KeyStore.read(provider) ?? (throw const GitException('Enginn API lykill vistaður. Settu hann inn í Stillingum.'));

  Future<Map<String, dynamic>> _post(Uri uri, Map<String, String> headers, Map<String, Object?> body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    final watch = Stopwatch()..start();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      headers.forEach(request.headers.set);
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(const Duration(minutes: 3));
      final text = await response.transform(utf8.decoder).join();
      _log('${uri.host} status=${response.statusCode} ${watch.elapsed.inSeconds}s');
      if (response.statusCode >= 300) {
        String detail = text;
        try {
          final error = (jsonDecode(text) as Map)['error'];
          detail = error is Map ? '${error['message'] ?? error}' : '$error';
        } on Object {
          // Not JSON: keep the raw body.
        }
        throw GitException('AI þjónustan svaraði ${response.statusCode}: $detail');
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } on SocketException catch (error) {
      throw GitException('Næ ekki sambandi við ${uri.host}: ${error.message}');
    } finally {
      client.close();
    }
  }

  /// Runs an agent inside [repo] to finish a task, streaming each step.
  Stream<AgentEvent> runAgent({required AgentProvider agent, required String repo, required String task}) => switch (agent) {
        AgentProvider.claudeCode => _claudeAgent(repo, task),
        AgentProvider.codex => _codexAgent(repo, task),
        AgentProvider.off => Stream.value(const AgentEvent('AI agent er óvirkur í Stillingum', done: true, failed: true)),
      };

  Stream<AgentEvent> _claudeAgent(String repo, String task) async* {
    if (claude == null) throw const GitException('Claude Code (claude) fannst ekki á þessari vél');
    final process = await Process.start(
      claude!,
      [
        '-p', task,
        '--model', 'sonnet',
        '--output-format', 'stream-json',
        '--verbose',
        '--no-session-persistence',
        '--strict-mcp-config',
        '--permission-mode', 'acceptEdits',
        '--allowedTools', 'Bash(git:*)', 'Read', 'Edit', 'Write', 'Grep', 'Glob',
      ],
      workingDirectory: repo,
      environment: _environment,
    );
    unawaited(process.stdin.close());
    unawaited(process.stderr.drain<void>());
    var finished = false;
    await for (final event in _jsonLines(process)) {
      switch (event['type']) {
        case 'assistant':
          for (final part in ((event['message']?['content'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
            if (part['type'] == 'tool_use') {
              final input = part['input'] as Map<String, dynamic>? ?? const {};
              yield AgentEvent('${part['name']}: ${input['command'] ?? input['file_path'] ?? input['pattern'] ?? ''}'.trim());
            }
          }
        case 'result':
          finished = true;
          final text = (event['result'] as String? ?? '').trim();
          final failed = event['is_error'] == true || text.contains('Failed to authenticate');
          yield AgentEvent(text.contains('Failed to authenticate') ? 'Claude Code er ekki innskráð (Stillingar → Skrá inn)' : text,
              done: true, failed: failed);
      }
    }
    final code = await process.exitCode;
    if (!finished) yield AgentEvent('Claude stoppaði (exit $code)', done: true, failed: true);
  }

  /// The sandbox keeps `.git` read-only unless it is listed as writable; worktrees keep it elsewhere.
  Future<List<String>> _gitDirs(String repo) async {
    final dirs = <String>{};
    for (final flag in ['--absolute-git-dir', '--git-common-dir']) {
      final result = await Process.run('git', ['rev-parse', flag], workingDirectory: repo, environment: env.environment);
      final path = (result.stdout as String).trim();
      if (result.exitCode == 0 && path.isNotEmpty) dirs.add(path.startsWith('/') ? path : '$repo/$path');
    }
    return dirs.toList();
  }

  Stream<AgentEvent> _codexAgent(String repo, String task) async* {
    if (codex == null) throw const GitException('Codex (codex) fannst ekki á þessari vél');
    final process = await Process.start(
      codex!,
      [
        'exec', '--json', '--color', 'never', '--ephemeral', '--skip-git-repo-check',
        '--sandbox', 'workspace-write',
        '-c', 'sandbox_workspace_write.network_access=true',
        '-c', 'sandbox_workspace_write.writable_roots=${jsonEncode(await _gitDirs(repo))}',
        '-c', 'mcp_servers={}',
        '--cd', repo,
        task,
      ],
      workingDirectory: repo,
      environment: _environment,
    );
    unawaited(process.stdin.close());
    unawaited(process.stderr.drain<void>());
    var last = '';
    var failed = false;
    await for (final event in _jsonLines(process)) {
      final item = event['item'] as Map<String, dynamic>?;
      if (event['type'] == 'item.started' && item?['type'] == 'command_execution') {
        final command = '${item!['command']}';
        yield AgentEvent(RegExp(r'''^/bin/zsh -lc (['"])(.*)\1$''').firstMatch(command)?.group(2) ?? command);
      } else if (event['type'] == 'item.completed' && item?['type'] == 'agent_message') {
        last = '${item!['text']}'.trim();
        yield AgentEvent(last);
      } else if (event['type'] == 'turn.failed') {
        failed = true;
        last = '${(event['error'] as Map?)?['message'] ?? 'Codex mistókst'}';
      }
    }
    final code = await process.exitCode;
    _log('codex agent exit=$code ${failed ? 'turn failed' : ''}');
    yield AgentEvent(last.isEmpty ? 'Codex kláraði (exit $code)' : last, done: true, failed: failed || code != 0);
  }

  static Stream<Map<String, dynamic>> _jsonLines(Process process) async* {
    await for (final line in process.stdout.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter())) {
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) yield decoded;
      } on FormatException {
        continue;
      }
    }
  }
}
