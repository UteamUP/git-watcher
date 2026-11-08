import 'dart:convert';
import 'dart:io';

import 'ai.dart';

/// Settings shared by the app and the MCP server, so agents see the same repos as the window.
/// API keys are not here: they live in the macOS keychain (see [KeyStore]).
class WatcherConfig {
  WatcherConfig({
    required this.root,
    this.recursive = true,
    List<String>? recentRoots,
    Map<String, String>? icons,
    Set<String>? watchedCi,
    Set<String>? hidden,
    this.aiProvider,
    Map<String, String>? aiModels,
    Map<String, String>? aiBaseUrls,
    this.agent,
    this.language = 'en',
  })  : recentRoots = recentRoots ?? [],
        icons = icons ?? {},
        watchedCi = watchedCi ?? {},
        hidden = hidden ?? {},
        aiModels = aiModels ?? {},
        aiBaseUrls = aiBaseUrls ?? {};

  String root;
  bool recursive;
  final List<String> recentRoots;

  /// Repo path to a custom icon image chosen by the user.
  final Map<String, String> icons;

  /// Repo paths whose CI the user is watching closely.
  final Set<String> watchedCi;

  /// Repo paths the user has hidden from the grid.
  final Set<String> hidden;

  /// Null until chosen; the app then picks a provider that is signed in.
  AiProvider? aiProvider;
  final Map<String, String> aiModels;
  final Map<String, String> aiBaseUrls;
  AgentProvider? agent;

  /// The app's language code: en (the default) or is.
  String language;

  static String get _home => Platform.environment['HOME'] ?? '/';

  static File get file => File('$_home/.uteamup/gitwatcher.json');

  static String get mcpBinaryPath => '$_home/.local/bin/git-watcher-mcp';

  static String defaultRoot() {
    final activeProjects = '$_home/UteamUP_Development/ActiveProjects';
    return Directory(activeProjects).existsSync() ? activeProjects : _home;
  }

  AiSettings aiSettings(AiProvider provider) => AiSettings(
        provider: provider,
        model: aiModels[provider.name] ?? provider.defaultModel,
        baseUrl: aiBaseUrls[provider.name] ?? provider.defaultBaseUrl,
      );

  static WatcherConfig load() {
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final root = json['root'] as String?;
      return WatcherConfig(
        root: root != null && Directory(root).existsSync() ? root : defaultRoot(),
        recursive: json['recursive'] as bool? ?? true,
        recentRoots: [...?(json['recentRoots'] as List?)?.cast<String>()],
        icons: {...?(json['icons'] as Map?)?.cast<String, String>()},
        watchedCi: {...?(json['watchedCi'] as List?)?.cast<String>()},
        hidden: {...?(json['hidden'] as List?)?.cast<String>()},
        aiProvider: AiProvider.byName(json['aiProvider'] as String?),
        aiModels: {...?(json['aiModels'] as Map?)?.cast<String, String>()},
        aiBaseUrls: {...?(json['aiBaseUrls'] as Map?)?.cast<String, String>()},
        agent: AgentProvider.byName(json['agent'] as String?),
        language: json['language'] as String? ?? 'en',
      );
    } on Object {
      return WatcherConfig(root: defaultRoot());
    }
  }

  void save() {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'root': root,
      'recursive': recursive,
      'recentRoots': recentRoots,
      'icons': icons,
      'watchedCi': watchedCi.toList(),
      'hidden': hidden.toList(),
      'aiProvider': aiProvider?.name,
      'aiModels': aiModels,
      'aiBaseUrls': aiBaseUrls,
      'agent': agent?.name,
      'language': language,
    }));
  }

  void useRoot(String path) {
    root = path;
    recentRoots
      ..remove(path)
      ..insert(0, path);
    if (recentRoots.length > 6) recentRoots.removeRange(6, recentRoots.length);
  }
}
