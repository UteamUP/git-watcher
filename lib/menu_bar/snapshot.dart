/// What the menu bar shows about one repository: the work waiting and the pipeline running.
///
/// The panel lives in its own Flutter engine, so everything it shows travels over a channel
/// as plain data.
class MenuBarRepo {
  const MenuBarRepo({
    required this.path,
    required this.name,
    this.iconPath,
    required this.branch,
    required this.files,
    required this.fileCount,
    required this.added,
    required this.deleted,
    required this.ahead,
    required this.behind,
    required this.ciState,
    required this.ciProgress,
    this.ciText,
    this.busy,
    this.lastCommit,
  });

  final String path;
  final String name;
  final String? iconPath;
  final String branch;

  /// The first few changed files, so the panel can name them.
  final List<MenuBarFile> files;

  /// How many files changed in total, which can be more than [files] holds.
  final int fileCount;

  final int added;
  final int deleted;
  final int ahead;
  final int behind;

  /// 'none', 'queued', 'running', 'success', 'failure' or 'cancelled'.
  final String ciState;

  /// How far the pipeline has come, between 0 and 1.
  final double ciProgress;

  /// The pipeline in the user's language, already written by the main app.
  final String? ciText;

  /// What the app is doing to this repository right now.
  final String? busy;

  final String? lastCommit;

  bool get dirty => fileCount > 0;

  bool get ciRunning => ciState == 'running' || ciState == 'queued';

  factory MenuBarRepo.fromJson(Map<String, dynamic> json) => MenuBarRepo(
        path: json['path'] as String? ?? '',
        name: json['name'] as String? ?? '',
        iconPath: json['iconPath'] as String?,
        branch: json['branch'] as String? ?? '',
        files: [
          for (final file in (json['files'] as List? ?? const []))
            MenuBarFile.fromJson((file as Map).cast<String, dynamic>()),
        ],
        fileCount: json['fileCount'] as int? ?? 0,
        added: json['added'] as int? ?? 0,
        deleted: json['deleted'] as int? ?? 0,
        ahead: json['ahead'] as int? ?? 0,
        behind: json['behind'] as int? ?? 0,
        ciState: json['ciState'] as String? ?? 'none',
        ciProgress: (json['ciProgress'] as num?)?.toDouble() ?? 0,
        ciText: json['ciText'] as String?,
        busy: json['busy'] as String?,
        lastCommit: json['lastCommit'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'iconPath': iconPath,
        'branch': branch,
        'files': [for (final file in files) file.toJson()],
        'fileCount': fileCount,
        'added': added,
        'deleted': deleted,
        'ahead': ahead,
        'behind': behind,
        'ciState': ciState,
        'ciProgress': ciProgress,
        'ciText': ciText,
        'busy': busy,
        'lastCommit': lastCommit,
      };
}

/// One changed file in the menu bar panel.
class MenuBarFile {
  const MenuBarFile({required this.path, required this.name, required this.kind});

  final String path;
  final String name;

  /// The name of a ChangeKind: modified, added, deleted, renamed, untracked or conflicted.
  final String kind;

  factory MenuBarFile.fromJson(Map<String, dynamic> json) => MenuBarFile(
        path: json['path'] as String? ?? '',
        name: json['name'] as String? ?? '',
        kind: json['kind'] as String? ?? 'modified',
      );

  Map<String, dynamic> toJson() => {'path': path, 'name': name, 'kind': kind};
}

/// Everything the menu bar panel shows at one moment.
class MenuBarSnapshot {
  const MenuBarSnapshot({
    required this.dirty,
    required this.ahead,
    required this.ciRunning,
    required this.ciFailed,
    required this.repos,
    this.notice,
    this.noticeError = false,
  });

  /// How many repositories have uncommitted changes.
  final int dirty;

  /// How many repositories have commits waiting to be pushed.
  final int ahead;

  /// How many pipelines are running.
  final int ciRunning;

  /// How many pipelines failed.
  final int ciFailed;

  /// Only the repositories that have something waiting.
  final List<MenuBarRepo> repos;

  /// A short line about what just happened, from the last action in the panel.
  final String? notice;

  final bool noticeError;

  factory MenuBarSnapshot.fromJson(Map<String, dynamic> json) => MenuBarSnapshot(
        dirty: json['dirty'] as int? ?? 0,
        ahead: json['ahead'] as int? ?? 0,
        ciRunning: json['ciRunning'] as int? ?? 0,
        ciFailed: json['ciFailed'] as int? ?? 0,
        repos: [
          for (final repo in (json['repos'] as List? ?? const []))
            MenuBarRepo.fromJson((repo as Map).cast<String, dynamic>()),
        ],
        notice: json['notice'] as String?,
        noticeError: json['noticeError'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'dirty': dirty,
        'ahead': ahead,
        'ciRunning': ciRunning,
        'ciFailed': ciFailed,
        'repos': [for (final repo in repos) repo.toJson()],
        'notice': notice,
        'noticeError': noticeError,
      };
}
