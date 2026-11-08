import 'package:git_watcher_core/git_watcher_core.dart';

const _months = ['jan', 'feb', 'mar', 'apr', 'maí', 'jún', 'júl', 'ágú', 'sep', 'okt', 'nóv', 'des'];

String relativeTime(DateTime? time, {DateTime? now}) {
  if (time == null) return 'ekkert commit';
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return 'rétt í þessu';
  if (diff.inMinutes < 60) return 'fyrir ${diff.inMinutes} mín';
  if (diff.inHours < 24) return 'fyrir ${diff.inHours} klst';
  if (diff.inDays == 1) return 'í gær';
  if (diff.inDays < 7) return 'fyrir ${diff.inDays} dögum';
  if (diff.inDays < 14) return 'fyrir viku';
  if (diff.inDays < 31) return 'fyrir ${diff.inDays ~/ 7} vikum';
  return '${time.day}. ${_months[time.month - 1]}${time.year == current.year ? '' : ' ${time.year}'}';
}

String shortDuration(Duration? duration) {
  if (duration == null) return '';
  if (duration.inMinutes < 1) return '< 1 mín';
  if (duration.inMinutes < 60) return '${duration.inMinutes} mín';
  return '${duration.inHours} klst ${duration.inMinutes % 60} mín';
}

String kindLabel(ChangeKind kind) => switch (kind) {
      ChangeKind.modified => 'breytt',
      ChangeKind.added => 'ný',
      ChangeKind.deleted => 'eytt',
      ChangeKind.renamed => 'færð',
      ChangeKind.untracked => 'óskráð',
      ChangeKind.conflicted => 'árekstur',
    };

String ciLabel(CiStatus ci) => switch (ci.state) {
      CiState.none => 'Ekkert CI pipeline',
      CiState.queued => ['Í biðröð', if (ci.remaining != null) timeLeft(ci.remaining!)].join(' · '),
      CiState.running => ['${ci.doneJobs} af ${ci.totalJobs} verkum', if (ci.remaining != null) timeLeft(ci.remaining!)].join(' · '),
      CiState.success => 'Tókst · ${shortDuration(ci.duration)}',
      CiState.failure => ci.failedJob == null ? 'Mistókst' : 'Mistókst í ${ci.failedJob}',
      CiState.cancelled => 'Hætt við',
    };

String timeLeft(Duration left) => left.inSeconds < 45 ? 'næstum búið' : '≈ ${(left.inSeconds / 60).ceil()} mín eftir';

String aheadLabel(int n) => n == 1 ? '1 commit bíður push' : '$n commit bíða push';

String behindLabel(int n) => '$n commit á eftir remote';

/// 2171 becomes 2k so a count always fits inside a button.
String compactCount(int n) => n < 1000 ? '$n' : '${(n / 1000).round()}k';

/// How long an answer usually takes, so a spinner never looks like nothing is happening.
String providerSpeed(AiProvider provider) => switch (provider) {
      AiProvider.codex => 'getur tekið allt að mínútu',
      AiProvider.claudeCode => 'tekur nokkrar sekúndur',
      _ => 'tekur 1–5 sekúndur',
    };

String fileCount(int n) => n == 1 ? '1 skrá' : '$n skrár';

String operationLabel(RepoOperation operation) => switch (operation) {
      RepoOperation.rebase => 'rebase',
      RepoOperation.merge => 'merge',
      RepoOperation.cherryPick => 'cherry-pick',
      RepoOperation.none => '',
    };

/// The first line of an error, short enough for a progress row.
String firstLine(Object error) {
  final line = error.toString().trim().split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '$error');
  return line.length > 140 ? '${line.substring(0, 140)}…' : line;
}

String providerLabel(AiProvider provider) => switch (provider) {
      AiProvider.claudeCode => 'Claude Code',
      AiProvider.codex => 'Codex',
      AiProvider.anthropic => 'Anthropic API',
      AiProvider.openai => 'OpenAI API',
      AiProvider.deepseek => 'DeepSeek API',
      AiProvider.gemini => 'Google Gemini API',
      AiProvider.custom => 'OpenAI-samhæft API',
    };

String agentLabel(AgentProvider agent) => switch (agent) {
      AgentProvider.claudeCode => 'Claude Code',
      AgentProvider.codex => 'Codex',
      AgentProvider.off => 'Slökkt',
    };

/// Shows a path with the home folder as ~.
String homePath(String path, String home) => path.startsWith(home) ? '~${path.substring(home.length)}' : path;
