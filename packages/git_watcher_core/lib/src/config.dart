import 'dart:convert';
import 'dart:io';

import 'ai.dart';
import 'models.dart';

/// One skill to run in sequence when new commits arrive in a repository.
class SkillStepConfig {
  SkillStepConfig({
    required this.skill,
    this.agent = AgentProvider.claudeCode,
    this.model = '',
    this.enabled = true,
  });

  String skill;
  AgentProvider agent;

  /// Model alias or ID for the chosen CLI agent (empty uses the CLI's default).
  String model;
  bool enabled;

  factory SkillStepConfig.fromJson(Map<String, dynamic> json) {
    final parsedAgent = AgentProvider.byName(json['agent'] as String?);
    return SkillStepConfig(
      skill: (json['skill'] as String? ?? '').trim(),
      agent: parsedAgent == null || parsedAgent == AgentProvider.off ? AgentProvider.claudeCode : parsedAgent,
      model: (json['model'] as String? ?? '').trim(),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, Object?> toJson() => {
        'skill': skill.trim(),
        'agent': agent.name,
        if (model.trim().isNotEmpty) 'model': model.trim(),
        'enabled': enabled,
      };
}

/// Per-repository periodic automation: independent auto-commit / auto-push, plus commit-triggered skills.
class RepoAutomationConfig {
  RepoAutomationConfig({
    this.autoCommit = false,
    this.autoPush = false,
    int syncIntervalMinutes = 15,
    int? pushIntervalMinutes,
    this.watchCommitsForSkills = false,
    int skillIntervalMinutes = 15,
    List<SkillStepConfig>? skills,
    this.lastSkillCommit,
  })  : syncIntervalMinutes = syncIntervalMinutes.clamp(1, 1440),
        pushIntervalMinutes = (pushIntervalMinutes ?? syncIntervalMinutes).clamp(1, 1440),
        skillIntervalMinutes = skillIntervalMinutes.clamp(1, 1440),
        skills = skills ?? [];

  bool autoCommit;
  bool autoPush;

  /// Interval in minutes between automatic commits.
  int syncIntervalMinutes;

  /// Interval in minutes between automatic pushes (defaults to [syncIntervalMinutes] when not set separately).
  int pushIntervalMinutes;

  bool watchCommitsForSkills;
  int skillIntervalMinutes;
  final List<SkillStepConfig> skills;

  /// Last HEAD commit hash seen by the skill watcher, updated after skills finish to prevent re-trigger loops.
  String? lastSkillCommit;

  bool get hasAutoSync => autoCommit || autoPush;
  bool get hasActiveSkills => skills.any((s) => s.enabled && s.skill.trim().isNotEmpty);
  bool get hasSkillWatch => watchCommitsForSkills && hasActiveSkills;
  bool get hasAnyAutomation => hasAutoSync || hasSkillWatch;
  bool get isEmpty => !autoCommit && !autoPush && !watchCommitsForSkills && skills.isEmpty;

  factory RepoAutomationConfig.fromJson(Map<String, dynamic> json) {
    final syncMinutes = (json['syncIntervalMinutes'] as num?)?.toInt() ?? 15;
    return RepoAutomationConfig(
      autoCommit: json['autoCommit'] as bool? ?? false,
      autoPush: json['autoPush'] as bool? ?? false,
      syncIntervalMinutes: syncMinutes,
      pushIntervalMinutes: (json['pushIntervalMinutes'] as num?)?.toInt() ?? syncMinutes,
      watchCommitsForSkills: json['watchCommitsForSkills'] as bool? ?? false,
      skillIntervalMinutes: (json['skillIntervalMinutes'] as num?)?.toInt() ?? 15,
      skills: [
        for (final item in (json['skills'] as List? ?? const []))
          if (item is Map) SkillStepConfig.fromJson(item.cast<String, dynamic>()),
      ],
      lastSkillCommit: json['lastSkillCommit'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
        'autoCommit': autoCommit,
        'autoPush': autoPush,
        'syncIntervalMinutes': syncIntervalMinutes,
        'pushIntervalMinutes': pushIntervalMinutes,
        'watchCommitsForSkills': watchCommitsForSkills,
        'skillIntervalMinutes': skillIntervalMinutes,
        'skills': [for (final s in skills) s.toJson()],
        if (lastSkillCommit != null && lastSkillCommit!.isNotEmpty) 'lastSkillCommit': lastSkillCommit,
      };
}

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
    Map<String, RepoAutomationConfig>? repoAutomation,
    this.aiProvider,
    Map<String, String>? aiModels,
    Map<String, String>? aiBaseUrls,
    this.agent,
    this.language = 'en',
  })  : recentRoots = recentRoots ?? [],
        icons = icons ?? {},
        watchedCi = watchedCi ?? {},
        hidden = hidden ?? {},
        repoAutomation = repoAutomation ?? {},
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

  /// Per-repository periodic automation settings keyed by normalized disk path.
  final Map<String, RepoAutomationConfig> repoAutomation;

  /// Null until chosen; the app then picks a provider that is signed in.
  AiProvider? aiProvider;
  final Map<String, String> aiModels;
  final Map<String, String> aiBaseUrls;
  AgentProvider? agent;

  /// The app's language code: en (the default) or is.
  String language;

  static String get _home =>
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      (Platform.isWindows ? r'C:\' : '/');

  static File get file => File('$_home${Platform.pathSeparator}.uteamup${Platform.pathSeparator}gitwatcher.json');

  static String get mcpBinaryPath => '$_home${Platform.pathSeparator}.local${Platform.pathSeparator}bin${Platform.pathSeparator}git-watcher-mcp${Platform.isWindows ? '.exe' : ''}';

  static String defaultRoot() {
    final candidates = [
      '$_home${Platform.pathSeparator}UteamUP_Development${Platform.pathSeparator}ActiveProjects',
      if (Platform.isWindows) r'C:\UteamUP_Development\ActiveProjects',
    ];
    for (final dir in candidates) {
      if (Directory(dir).existsSync()) return dir;
    }
    return _home;
  }

  AiSettings aiSettings(AiProvider provider) => AiSettings(
        provider: provider,
        model: aiModels[provider.name] ?? provider.defaultModel,
        baseUrl: aiBaseUrls[provider.name] ?? provider.defaultBaseUrl,
      );

  RepoAutomationConfig? maybeAutomation(String repoPath) => repoAutomation[formatDiskPath(repoPath)];

  RepoAutomationConfig ensureAutomation(String repoPath) =>
      repoAutomation.putIfAbsent(formatDiskPath(repoPath), RepoAutomationConfig.new);

  void pruneAutomation(String repoPath) {
    final key = formatDiskPath(repoPath);
    final current = repoAutomation[key];
    if (current != null && current.isEmpty) repoAutomation.remove(key);
  }

  static WatcherConfig load() {
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final root = json['root'] as String?;
      final rawAutomation = json['repoAutomation'] as Map?;
      final parsedAutomation = <String, RepoAutomationConfig>{
        if (rawAutomation != null)
          for (final entry in rawAutomation.entries)
            if (entry.key is String && entry.value is Map)
              formatDiskPath(entry.key as String): RepoAutomationConfig.fromJson((entry.value as Map).cast<String, dynamic>()),
      };
      return WatcherConfig(
        root: root != null && Directory(root).existsSync() ? root : defaultRoot(),
        recursive: json['recursive'] as bool? ?? true,
        recentRoots: [...?(json['recentRoots'] as List?)?.cast<String>()],
        icons: {...?(json['icons'] as Map?)?.cast<String, String>()},
        watchedCi: {...?(json['watchedCi'] as List?)?.cast<String>()},
        hidden: {...?(json['hidden'] as List?)?.cast<String>()},
        repoAutomation: parsedAutomation,
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
      'repoAutomation': {
        for (final entry in repoAutomation.entries)
          if (!entry.value.isEmpty) entry.key: entry.value.toJson(),
      },
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
