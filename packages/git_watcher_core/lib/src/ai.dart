import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'git.dart';
import 'process_env.dart';

/// Where commit messages come from: a local CLI on the user's subscription, or an API key.
enum AiProvider {
  claudeCode(cli: true),
  codex(cli: true),
  anthropic(
    defaultModel: 'claude-opus-5-5',
    defaultBaseUrl: 'https://api.anthropic.com',
    suggestedModels: ['claude-opus-5-5', 'claude-sonnet-5-5', 'claude-haiku-5-5'],
  ),
  openai(
    defaultModel: 'gpt-5-mini',
    defaultBaseUrl: 'https://api.openai.com/v1',
    suggestedModels: ['gpt-5-mini', 'gpt-5', 'gpt-6.1', 'chat-latest', 'o4-mini'],
  ),
  deepseek(
    defaultModel: 'deepseek-flash',
    defaultBaseUrl: 'https://api.deepseek.com',
    suggestedModels: ['deepseek-flash', 'deepseek-v4-pro', 'deepseek-chat', 'deepseek-reasoner'],
  ),
  minimax(
    defaultModel: 'MiniMax-M3',
    defaultBaseUrl: 'https://api.minimax.io/v1',
    suggestedModels: ['MiniMax-M3', 'MiniMax-M3.1-Flash'],
  ),
  kimi(
    defaultModel: 'kimi-k3.1-pro',
    defaultBaseUrl: 'https://api.moonshot.ai/v1',
    suggestedModels: ['kimi-k3.1-pro', 'kimi-k3.1-pro-highspeed', 'kimi-k3', 'kimi-k2.6'],
  ),
  gemini(
    defaultModel: 'gemini-2.5-flash',
    defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    suggestedModels: ['gemini-3.6-flash', 'gemini-3.1-pro-preview', 'gemini-2.5-flash', 'gemini-flash-latest'],
  ),
  xai(
    defaultModel: 'grok-4.7',
    defaultBaseUrl: 'https://api.x.ai/v1',
    suggestedModels: ['grok-4.7', 'grok-4.6', 'grok-4.5', 'latest'],
  ),
  mistral(
    defaultModel: 'mistral-small-latest',
    defaultBaseUrl: 'https://api.mistral.ai/v1',
    suggestedModels: ['mistral-small-latest', 'codestral-latest', 'mistral-medium-latest', 'mistral-large-latest'],
  ),
  groq(
    defaultModel: 'llama-3.3-70b-versatile',
    defaultBaseUrl: 'https://api.groq.com/openai/v1',
    suggestedModels: ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant', 'openai/gpt-oss-120b', 'openai/gpt-oss-20b'],
  ),
  openrouter(
    defaultModel: 'minimax/minimax-m3',
    defaultBaseUrl: 'https://openrouter.ai/api/v1',
    suggestedModels: [
      'minimax/minimax-m3',
      'moonshotai/kimi-k3.1-pro',
      'deepseek/deepseek-v4-pro',
      'anthropic/claude-haiku-5-5',
      'anthropic/claude-sonnet-5-5',
      'google/gemini-2.5-flash',
    ],
  ),
  custom(defaultModel: '', defaultBaseUrl: 'https://openrouter.ai/api/v1');

  const AiProvider({
    this.cli = false,
    this.defaultModel = '',
    this.defaultBaseUrl = '',
    this.suggestedModels = const [],
  });

  final bool cli;
  final String defaultModel;
  final String defaultBaseUrl;
  final List<String> suggestedModels;

  bool get needsKey => !cli;

  static AiProvider? byName(String? name) => AiProvider.values.where((p) => p.name == name).firstOrNull;
}

/// Agents that can run git themselves to fix a failed commit, rebase or push, or execute skills.
enum AgentProvider {
  claudeCode(
    defaultSkillModel: 'sonnet',
    suggestedSkillModels: ['sonnet', 'opus', 'haiku', 'claude-opus-4-6', 'claude-sonnet-4-6'],
  ),
  codex(
    defaultSkillModel: '',
    suggestedSkillModels: ['gpt-5.4', 'gpt-5.3-codex', 'gpt-5-codex', 'o3', 'o4-mini'],
  ),
  off;

  const AgentProvider({
    this.defaultSkillModel = '',
    this.suggestedSkillModels = const [],
  });

  final String defaultSkillModel;
  final List<String> suggestedSkillModels;

  static AgentProvider? byName(String? name) => AgentProvider.values.where((p) => p.name == name).firstOrNull;
}

class AiSettings {
  const AiSettings({required this.provider, required this.model, required this.baseUrl});

  final AiProvider provider;
  final String model;
  final String baseUrl;
}

/// One line of progress from an agent run.
/// Fixed things the AI layer says, so the app can show them in the user's language.
/// [AiException.detail] and [AgentEvent.detail] hold the value each one is about.
enum AiText {
  badKey,
  keychainFailed,
  emptyReply,
  cliMissing,
  claudeSignedOut,
  timedOut,
  cliFailed,
  refused,
  noModel,
  noKey,
  httpStatus,
  unreachable,
  agentOff,
  agentStopped,
  agentFinished,
}

class AiException extends GitException {
  const AiException(this.kind, super.message, {this.detail = ''});

  final AiText kind;
  final String detail;
}

class AgentEvent {
  const AgentEvent(this.text, {this.done = false, this.failed = false, this.kind, this.detail = ''});

  /// What the agent said or ran, as it said it. When [kind] is set, the app shows its own wording instead.
  final String text;
  final bool done;
  final bool failed;
  final AiText? kind;
  final String detail;
}

/// API keys live in the macOS login keychain (or Windows DPAPI per-user store on Windows), never in plaintext.
class KeyStore {
  static const _service = 'GIT Watcher AI';
  static const _security = '/usr/bin/security';
  static final _windowsCache = <AiProvider, ({DateTime modified, String key})>{};

  static File _windowsKeyFile(AiProvider provider) {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? r'C:\';
    return File('$home\\.uteamup\\keys\\${provider.name}.dpapi');
  }

  static Future<String?> read(AiProvider provider) async {
    if (Platform.isWindows) {
      final file = _windowsKeyFile(provider);
      if (!await file.exists()) {
        _windowsCache.remove(provider);
        return null;
      }
      final stat = await file.stat();
      final cached = _windowsCache[provider];
      if (cached != null && cached.modified == stat.modified) return cached.key;

      final encrypted = (await file.readAsString()).replaceAll('\uFEFF', '').trim();
      if (encrypted.isEmpty) return null;
      const cmd = r"$enc = [Console]::In.ReadToEnd().Trim().Trim([char]0xFEFF); "
          r"if (-not $enc) { exit 1 }; "
          r"$s = ConvertTo-SecureString -String $enc; "
          r"[Console]::Out.Write([System.Net.NetworkCredential]::new('', $s).Password)";
      final process = await Process.start('powershell', ['-NoProfile', '-NonInteractive', '-Command', cmd]);
      process.stdin.write(encrypted);
      await process.stdin.close();
      final out = await process.stdout.transform(const Utf8Decoder(allowMalformed: true)).join();
      await process.stderr.drain<void>();
      final key = out.trim();
      if (await process.exitCode != 0 || key.isEmpty) return null;
      _windowsCache[provider] = (modified: stat.modified, key: key);
      return key;
    }
    final result = await Process.run(_security, ['find-generic-password', '-s', _service, '-a', provider.name, '-w']);
    final key = (result.stdout as String).trim();
    return result.exitCode == 0 && key.isNotEmpty ? key : null;
  }

  /// The key goes through stdin (`security -i` on macOS, PowerShell DPAPI on Windows), so it never shows up in the process list.
  static Future<void> write(AiProvider provider, String key) async {
    final value = key.replaceAll('\uFEFF', '').trim();
    if (value.isEmpty || RegExp(r'[\s"\\]').hasMatch(value)) {
      throw const AiException(AiText.badKey, 'The key must not be empty or contain spaces, quotes or backslashes');
    }
    if (Platform.isWindows) {
      final file = _windowsKeyFile(provider);
      await file.parent.create(recursive: true);
      const cmd = r"$plain = [Console]::In.ReadToEnd().Trim().Trim([char]0xFEFF); "
          r"if (-not $plain) { exit 1 }; "
          r"$s = ConvertTo-SecureString -String $plain -AsPlainText -Force; "
          r"[Console]::Out.Write(($s | ConvertFrom-SecureString))";
      final process = await Process.start('powershell', ['-NoProfile', '-NonInteractive', '-Command', cmd]);
      process.stdin.write(value);
      await process.stdin.close();
      final out = await process.stdout.transform(const Utf8Decoder(allowMalformed: true)).join();
      final err = (await process.stderr.transform(const Utf8Decoder(allowMalformed: true)).join()).trim();
      final encrypted = out.replaceAll('\uFEFF', '').trim();
      if (await process.exitCode != 0 || encrypted.isEmpty) {
        final detail = err.isEmpty ? 'DPAPI encryption failed' : err;
        throw AiException(AiText.keychainFailed, 'Could not save the key: $detail', detail: detail);
      }
      await file.writeAsString(encrypted, flush: true);
      _windowsCache.remove(provider);
      if (await read(provider) != value) {
        throw const AiException(AiText.keychainFailed, 'Could not verify the saved key', detail: 'DPAPI round-trip check failed');
      }
      return;
    }
    final process = await Process.start(_security, ['-i']);
    process.stdin.writeln('add-generic-password -U -s "$_service" -a "${provider.name}" -w "$value"');
    await process.stdin.close();
    final err = await process.stderr.transform(utf8.decoder).join();
    if (await process.exitCode != 0 || err.trim().isNotEmpty) {
      throw AiException(AiText.keychainFailed, 'Could not save the key in the Keychain: ${err.trim()}', detail: err.trim());
    }
  }

  static Future<void> delete(AiProvider provider) async {
    if (Platform.isWindows) {
      _windowsCache.remove(provider);
      final file = _windowsKeyFile(provider);
      if (await file.exists()) await file.delete();
      return;
    }
    await Process.run(_security, ['delete-generic-password', '-s', _service, '-a', provider.name]);
  }
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

  /// Strips reasoning `<think>...</think>` blocks and markdown code fences from raw model output.
  static String cleanCommitMessage(String raw, {bool subjectOnly = false}) {
    final withoutThink = raw
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .replaceAll(RegExp(r'^```[a-zA-Z0-9_-]*\s*|```\s*$', multiLine: true), '')
        .replaceAll('`', '')
        .trim();
    if (withoutThink.isEmpty) return '';
    return subjectOnly ? withoutThink.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => '') : withoutThink;
  }

  /// Normalizes a provider's base URL so trailing slashes or pasted endpoint suffixes still resolve cleanly.
  static String normalizeBaseUrl(AiSettings settings) {
    var base = (settings.baseUrl.trim().isEmpty ? settings.provider.defaultBaseUrl : settings.baseUrl.trim());
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    for (final suffix in const ['/chat/completions', '/v1/messages', '/messages']) {
      if (base.endsWith(suffix)) {
        base = base.substring(0, base.length - suffix.length);
        break;
      }
    }
    if (settings.provider == AiProvider.anthropic && base.endsWith('/v1')) {
      base = base.substring(0, base.length - 3);
    } else if (settings.provider != AiProvider.anthropic && settings.provider.defaultBaseUrl.endsWith('/v1')) {
      final uri = Uri.tryParse(base);
      if (uri != null && uri.hasAuthority && (uri.path.isEmpty || uri.path == '/')) {
        base = '$base/v1';
      }
    }
    return base;
  }

  /// Queries the provider's `/models` endpoint so users can pick any model ID available to their API key.
  Future<List<String>> listModels(AiSettings settings) async {
    if (settings.provider.cli) return const [];
    final key = await _key(settings.provider);
    final isAnthropic = settings.provider == AiProvider.anthropic;
    final base = normalizeBaseUrl(settings);
    final uri = Uri.parse('$base${isAnthropic ? '/v1/models' : '/models'}');
    final headers = isAnthropic
        ? {'x-api-key': key, 'anthropic-version': '2023-06-01'}
        : {'authorization': 'Bearer $key'};
    final json = await _get(uri, headers);
    final items = json['data'] as List? ?? json['models'] as List? ?? const [];
    final seen = <String>{};
    final models = <String>[];
    for (final item in items) {
      var id = item is Map ? '${item['id'] ?? item['name'] ?? ''}'.trim() : '$item'.trim();
      if (settings.provider == AiProvider.gemini && id.startsWith('models/')) {
        id = id.substring('models/'.length);
      }
      if (id.isNotEmpty && seen.add(id)) models.add(id);
    }
    return models;
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
    final message = cleanCommitMessage(raw, subjectOnly: subjectOnly);
    if (message.isEmpty) throw const AiException(AiText.emptyReply, 'The AI returned an empty message');
    return message;
  }

  static String _rules(bool subjectOnly) => '''
You write git commit messages.
- Conventional Commits: type(scope): subject. Types: feat, fix, chore, refactor, docs, test, perf, ci, style, build, remove.
- English, imperative mood, lowercase after the colon, no trailing period, at most 72 characters.
${subjectOnly ? '- Write only the subject line.' : '- Add a blank line and a short body (2-5 lines, each at most 100 characters) only when the change needs explaining.'}
- Never use backticks.
Reply with the commit message only, nothing else.''';

  Future<String> _claudeCli(String rules, String request) async {
    if (claude == null) throw const AiException(AiText.cliMissing, 'Claude Code (claude) was not found', detail: 'Claude Code');
    // --strict-mcp-config with no config: skip the user's MCP servers, which only slow a one-shot answer down.
    final out = await _run(
        claude!, ['-p', rules, '--model', 'haiku', '--no-session-persistence', '--strict-mcp-config', '--output-format', 'text'], request);
    if (out.contains('Failed to authenticate') || out.contains('Invalid API key') || out.contains('/login')) {
      throw const AiException(AiText.claudeSignedOut, 'Claude Code is not signed in');
    }
    return out;
  }

  Future<String> _codexCli(String rules, String request) async {
    if (codex == null) throw const AiException(AiText.cliMissing, 'Codex (codex) was not found', detail: 'Codex');
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
    final toolName = executable.split(RegExp(r'[/\\]')).last;
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
    _log('$toolName message exit=$code ${watch.elapsed.inSeconds}s '
        '${code == 0 ? '' : stderr.split('\n').where((l) => l.trim().isNotEmpty).lastOrNull ?? ''}');
    if (code != 0) {
      if (code == -1) throw AiException(AiText.timedOut, '$toolName did not answer within 3 minutes', detail: toolName);
      final detail = [stderr, stdout].firstWhere((s) => s.isNotEmpty, orElse: () => 'exit $code');
      throw AiException(AiText.cliFailed, 'The AI could not write a message: ${detail.split('\n').last}', detail: detail.split('\n').last);
    }
    return stdout;
  }

  Future<String> _anthropic(AiSettings settings, String rules, String request) async {
    final key = await _key(settings.provider);
    final model = settings.model.isEmpty ? settings.provider.defaultModel : settings.model;
    // Server-side fallback only exists for these models; it reroutes a policy decline instead of failing.
    final fallback = const {'claude-opus-5-5', 'claude-opus-5', 'claude-fable-5-1', 'claude-sonnet-5-5'}.contains(model);
    final json = await _post(
      Uri.parse('${normalizeBaseUrl(settings)}/v1/messages'),
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
    if (json['stop_reason'] == 'refusal') throw const AiException(AiText.refused, 'Claude declined to write this message');
    return [
      for (final block in (json['content'] as List? ?? const []).cast<Map<String, dynamic>>())
        if (block['type'] == 'text') block['text'] as String,
    ].join();
  }

  Future<String> _openAiCompatible(AiSettings settings, String rules, String request) async {
    final key = await _key(settings.provider);
    final model = settings.model.isEmpty ? settings.provider.defaultModel : settings.model;
    if (model.isEmpty) throw const AiException(AiText.noModel, 'Choose a model in Settings');
    final json = await _post(
      Uri.parse('${normalizeBaseUrl(settings)}/chat/completions'),
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
    if (choices.isEmpty) throw const AiException(AiText.emptyReply, 'The AI returned no answer');
    final msg = (choices.first as Map)['message'] as Map? ?? const {};
    return msg['content'] as String? ?? '';
  }

  static Future<String> _key(AiProvider provider) async =>
      await KeyStore.read(provider) ?? (throw const AiException(AiText.noKey, 'No API key saved. Add one in Settings.'));

  Future<Map<String, dynamic>> _get(Uri uri, Map<String, String> headers) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    final watch = Stopwatch()..start();
    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(const Duration(seconds: 30));
      final text = await response.transform(utf8.decoder).join();
      _log('${uri.host} models status=${response.statusCode} ${watch.elapsed.inSeconds}s');
      if (response.statusCode >= 300) {
        throw AiException(AiText.httpStatus, 'The AI service answered ${response.statusCode}: ${_extractHttpError(text)}',
            detail: '${response.statusCode}: ${_extractHttpError(text)}');
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } on SocketException catch (error) {
      throw AiException(AiText.unreachable, 'Cannot reach ${uri.host}: ${error.message}', detail: uri.host);
    } finally {
      client.close();
    }
  }

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
        final detail = _extractHttpError(text);
        throw AiException(AiText.httpStatus, 'The AI service answered ${response.statusCode}: $detail',
            detail: '${response.statusCode}: $detail');
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } on SocketException catch (error) {
      throw AiException(AiText.unreachable, 'Cannot reach ${uri.host}: ${error.message}', detail: uri.host);
    } finally {
      client.close();
    }
  }

  static String _extractHttpError(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final error = decoded['error'] ?? decoded['base_resp'] ?? decoded['message'];
        if (error is Map) return '${error['message'] ?? error['status_msg'] ?? error}';
        if (error != null) return '$error';
      }
    } on Object {
      // Not JSON: keep the raw body.
    }
    return text;
  }

  /// Runs an agent inside [repo] to finish a task, streaming each step.
  Stream<AgentEvent> runAgent({required AgentProvider agent, required String repo, required String task}) => switch (agent) {
        AgentProvider.claudeCode => _claudeAgent(repo, task),
        AgentProvider.codex => _codexAgent(repo, task),
        AgentProvider.off => Stream.value(const AgentEvent('The AI agent is turned off in Settings', done: true, failed: true, kind: AiText.agentOff)),
      };

  static const _skillSubdirs = [
    '.claude/skills',
    '.agent/skills',
    '.agents/skills',
    '.codex/skills',
  ];

  /// Splits a skill invocation such as `/uteamup-cli upgrade` into `(name: 'uteamup-cli', args: 'upgrade')`.
  static ({String name, String args}) parseSkillSpec(String raw) {
    final trimmed = raw.trim().replaceFirst(RegExp(r'^/+'), '').trim();
    if (trimmed.isEmpty) return (name: '', args: '');
    final match = RegExp(r'^(\S+)(?:\s+([\s\S]+))?$').firstMatch(trimmed);
    if (match == null) return (name: trimmed, args: '');
    return (name: match.group(1)!, args: (match.group(2) ?? '').trim());
  }

  static bool _looksLikeSkillMissingRefusal(String text) {
    final lower = text.toLowerCase();
    return (lower.contains('there is no ') && lower.contains('skill installed')) ||
        lower.contains('skill is not installed') ||
        lower.contains('unknown skill:');
  }

  Map<String, String> _skillEnvironment({required String root, required String repo}) {
    final base = _environment;
    final sep = Platform.isWindows ? ';' : ':';
    final extraBins = <String>[
      if (repo.isNotEmpty) '$repo${Platform.pathSeparator}bin',
      if (root.isNotEmpty) '$root${Platform.pathSeparator}uteamup_cli${Platform.pathSeparator}bin',
      if (repo.isNotEmpty) '${Directory(repo).parent.path}${Platform.pathSeparator}uteamup_cli${Platform.pathSeparator}bin',
    ].where((d) => Directory(d).existsSync()).toList();
    final existingPath = base.entries
        .where((e) => e.key.toUpperCase() == 'PATH')
        .map((e) => e.value)
        .join(sep);
    base.removeWhere((k, _) => k.toUpperCase() == 'PATH');
    base['PATH'] = <String>[
      ...extraBins,
      ...existingPath.split(sep),
    ].where((d) => d.isNotEmpty).toSet().join(sep);
    return base;
  }

  static String _buildSkillPrompt({
    required String skill,
    required String? skillFile,
    required String repo,
    required String root,
  }) {
    final spec = parseSkillSpec(skill);
    final argsClause = spec.args.isEmpty ? 'using its default workflow' : 'with arguments "${spec.args}"';
    if (skillFile != null) {
      final skillDir = File(skillFile).parent.path;
      final workspaceNote = root.isNotEmpty && root != repo ? ' (workspace root: "$root")' : '';
      return 'Execute the "${spec.name}" skill $argsClause in repository "$repo"$workspaceNote. '
          'IMPORTANT: First read "$skillFile" directly from disk using your file-reading tool — '
          'do NOT invoke a built-in slash command or Skill lookup because this skill lives at "$skillDir" (which may be under .agent/skills rather than .claude/skills). '
          'Resolve any relative paths referenced by the skill (such as scripts/, references/, or LEARNINGS.md) against "$skillDir" and workspace "$root". '
          'Follow every required step in "$skillFile" ${spec.args.isEmpty ? "for this repository" : "for \"${spec.args}\""} autonomously without asking interactive questions, then end with one short summary sentence.';
    }
    return 'Run /$skill in repository "$repo". '
        'Execute every required step autonomously without asking interactive questions, then end with one short summary sentence.';
  }

  /// Discovers installed skill names across [repo], [root], and the user's home directory.
  List<String> discoverSkills({required String root, String? repo}) {
    final bases = <String>{
      if (repo != null && repo.isNotEmpty) repo,
      if (root.isNotEmpty) root,
      if (repo != null && repo.isNotEmpty) Directory(repo).parent.path,
      if (env.home.isNotEmpty) env.home,
    };
    final names = <String>{};
    for (final base in bases) {
      for (final sub in _skillSubdirs) {
        final dir = Directory('$base${Platform.pathSeparator}${sub.replaceAll('/', Platform.pathSeparator)}');
        if (!dir.existsSync()) continue;
        try {
          for (final entry in dir.listSync(followLinks: true)) {
            if (entry is! Directory) continue;
            final name = entry.path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).lastOrNull;
            if (name == null || name.startsWith('.')) continue;
            if (File('${entry.path}${Platform.pathSeparator}SKILL.md').existsSync()) {
              names.add(name);
            }
          }
        } on FileSystemException {
          continue;
        }
      }
    }
    return names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Resolves the path to `<skill>/SKILL.md` if present in [repo], [root], or the user's home directory.
  /// Leading slashes and trailing skill arguments (e.g. `uteamup-cli upgrade`) are stripped before lookup.
  String? resolveSkillFile(String skill, {required String root, required String repo}) {
    final clean = parseSkillSpec(skill).name;
    if (clean.isEmpty) return null;
    final bases = <String>{
      if (repo.isNotEmpty) repo,
      if (root.isNotEmpty) root,
      if (repo.isNotEmpty) Directory(repo).parent.path,
      if (env.home.isNotEmpty) env.home,
    };
    for (final base in bases) {
      for (final sub in _skillSubdirs) {
        final candidate = File(
          '$base${Platform.pathSeparator}${sub.replaceAll('/', Platform.pathSeparator)}${Platform.pathSeparator}$clean${Platform.pathSeparator}SKILL.md',
        );
        if (candidate.existsSync()) return candidate.path;
      }
    }
    return null;
  }

  /// Runs a named [skill] inside [repo] using [agent] and [model] with full tool/build permissions.
  Stream<AgentEvent> runSkill({
    required AgentProvider agent,
    required String repo,
    required String skill,
    String model = '',
    String root = '',
  }) {
    final cleanSkill = skill.trim().replaceFirst(RegExp(r'^/+'), '').trim();
    final skillFile = resolveSkillFile(cleanSkill, root: root, repo: repo);
    return switch (agent) {
      AgentProvider.claudeCode => _claudeSkill(repo: repo, root: root, skill: cleanSkill, skillFile: skillFile, model: model),
      AgentProvider.codex => _codexSkill(repo: repo, root: root, skill: cleanSkill, skillFile: skillFile, model: model),
      AgentProvider.off => Stream.value(const AgentEvent('The AI agent is turned off in Settings', done: true, failed: true, kind: AiText.agentOff)),
    };
  }

  Stream<AgentEvent> _claudeSkill({
    required String repo,
    required String root,
    required String skill,
    required String? skillFile,
    required String model,
  }) async* {
    if (claude == null) throw const AiException(AiText.cliMissing, 'Claude Code (claude) was not found', detail: 'Claude Code');
    final chosenModel = model.trim().isEmpty ? AgentProvider.claudeCode.defaultSkillModel : model.trim();
    final extraDirs = <String>{
      if (root.isNotEmpty && root != repo) root,
      if (skillFile != null) File(skillFile).parent.path,
    };
    final prompt = _buildSkillPrompt(skill: skill, skillFile: skillFile, repo: repo, root: root);
    final watch = Stopwatch()..start();
    final process = await Process.start(
      claude!,
      [
        '-p', prompt,
        '--model', chosenModel,
        '--output-format', 'stream-json',
        '--verbose',
        '--no-session-persistence',
        '--dangerously-skip-permissions',
        for (final dir in extraDirs) ...['--add-dir', dir],
      ],
      workingDirectory: repo,
      environment: _skillEnvironment(root: root, repo: repo),
    );
    unawaited(process.stdin.close());
    unawaited(process.stderr.drain<void>());
    var finished = false;
    var logged = false;
    try {
      await for (final event in _jsonLines(process)) {
        switch (event['type']) {
          case 'assistant':
            for (final part in ((event['message']?['content'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
              if (part['type'] == 'tool_use') {
                final input = part['input'] as Map<String, dynamic>? ?? const {};
                final detail = input['command'] ?? input['skill'] ?? input['file_path'] ?? input['pattern'] ?? '';
                yield AgentEvent('${part['name']}: $detail'.trim());
              }
            }
          case 'result':
            finished = true;
            final text = (event['result'] as String? ?? '').trim();
            final authFailed = text.contains('Failed to authenticate');
            final failed = event['is_error'] == true || authFailed || _looksLikeSkillMissingRefusal(text);
            yield authFailed
                ? const AgentEvent('Claude Code is not signed in', done: true, failed: true, kind: AiText.claudeSignedOut)
                : AgentEvent(text, done: true, failed: failed);
        }
      }
      final code = await process.exitCode;
      logged = true;
      _log('claude skill=$skill file=${skillFile ?? 'none'} model=$chosenModel exit=$code ${watch.elapsed.inSeconds}s');
      if (!finished) {
        yield AgentEvent('Claude stopped (exit $code)', done: true, failed: true, kind: AiText.agentStopped, detail: 'Claude (exit $code)');
      }
    } finally {
      if (!logged) {
        unawaited(
          process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
            process.kill();
            return -1;
          }).then((code) {
            _log('claude skill=$skill file=${skillFile ?? 'none'} model=$chosenModel exit=$code ${watch.elapsed.inSeconds}s');
          }),
        );
      }
    }
  }

  Stream<AgentEvent> _codexSkill({
    required String repo,
    required String root,
    required String skill,
    required String? skillFile,
    required String model,
  }) async* {
    if (codex == null) throw const AiException(AiText.cliMissing, 'Codex (codex) was not found', detail: 'Codex');
    final chosenModel = model.trim();
    final prompt = _buildSkillPrompt(skill: skill, skillFile: skillFile, repo: repo, root: root);
    final watch = Stopwatch()..start();
    final process = await Process.start(
      codex!,
      [
        'exec',
        '--json',
        '--color', 'never',
        '--ephemeral',
        '--skip-git-repo-check',
        '--dangerously-bypass-approvals-and-sandbox',
        if (chosenModel.isNotEmpty) ...['-m', chosenModel],
        '--cd', repo,
        prompt,
      ],
      workingDirectory: repo,
      environment: _skillEnvironment(root: root, repo: repo),
    );
    unawaited(process.stdin.close());
    unawaited(process.stderr.drain<void>());
    var last = '';
    var failed = false;
    var exited = false;
    try {
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
          last = '${(event['error'] as Map?)?['message'] ?? 'Codex failed'}';
        }
      }
      final code = await process.exitCode;
      exited = true;
      _log('codex skill=$skill file=${skillFile ?? 'none'} model=${chosenModel.isEmpty ? 'default' : chosenModel} exit=$code ${watch.elapsed.inSeconds}s');
      final ok = !failed && code == 0 && !_looksLikeSkillMissingRefusal(last);
      yield last.isEmpty
          ? AgentEvent('Codex ${ok ? 'finished' : 'stopped'} (exit $code)',
              done: true, failed: !ok, kind: ok ? AiText.agentFinished : AiText.agentStopped, detail: 'Codex (exit $code)')
          : AgentEvent(last, done: true, failed: !ok);
    } finally {
      if (!exited) process.kill();
    }
  }

  Stream<AgentEvent> _claudeAgent(String repo, String task) async* {
    if (claude == null) throw const AiException(AiText.cliMissing, 'Claude Code (claude) was not found', detail: 'Claude Code');
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
          yield text.contains('Failed to authenticate')
              ? const AgentEvent('Claude Code is not signed in', done: true, failed: true, kind: AiText.claudeSignedOut)
              : AgentEvent(text, done: true, failed: failed);
      }
    }
    final code = await process.exitCode;
    if (!finished) yield AgentEvent('Claude stopped (exit $code)', done: true, failed: true, kind: AiText.agentStopped, detail: 'Claude (exit $code)');
  }

  /// The sandbox keeps `.git` read-only unless it is listed as writable; worktrees keep it elsewhere.
  Future<List<String>> _gitDirs(String repo) async {
    final dirs = <String>{};
    for (final flag in ['--absolute-git-dir', '--git-common-dir']) {
      final result = await Process.run('git', ['rev-parse', flag], workingDirectory: repo, environment: env.environment);
      final path = (result.stdout as String).trim();
      final isAbsolute = RegExp(r'^([a-zA-Z]:[/\\]|/)').hasMatch(path);
      if (result.exitCode == 0 && path.isNotEmpty) dirs.add(isAbsolute ? path : '$repo${Platform.pathSeparator}$path');
    }
    return dirs.toList();
  }

  Stream<AgentEvent> _codexAgent(String repo, String task) async* {
    if (codex == null) throw const AiException(AiText.cliMissing, 'Codex (codex) was not found', detail: 'Codex');
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
        last = '${(event['error'] as Map?)?['message'] ?? 'Codex failed'}';
      }
    }
    final code = await process.exitCode;
    _log('codex agent exit=$code ${failed ? 'turn failed' : ''}');
    final ok = !failed && code == 0;
    yield last.isEmpty
        ? AgentEvent('Codex ${ok ? 'finished' : 'stopped'} (exit $code)',
            done: true, failed: !ok, kind: ok ? AiText.agentFinished : AiText.agentStopped, detail: 'Codex (exit $code)')
        : AgentEvent(last, done: true, failed: !ok);
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
