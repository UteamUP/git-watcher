import 'package:git_watcher_core/git_watcher_core.dart';
import 'package:intl/intl.dart';

import 'l10n/l10n.dart';

String relativeTime(AppLocalizations l, DateTime? time, {DateTime? now}) {
  if (time == null) return l.noCommits;
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.hoursAgo(diff.inHours);
  if (diff.inDays == 1) return l.yesterday;
  if (diff.inDays < 7) return l.daysAgo(diff.inDays);
  if (diff.inDays < 14) return l.aWeekAgo;
  if (diff.inDays < 31) return l.weeksAgo(diff.inDays ~/ 7);
  return (time.year == current.year ? DateFormat.MMMd(l.localeName) : DateFormat.yMMMd(l.localeName)).format(time);
}

String shortDuration(AppLocalizations l, Duration? duration) {
  if (duration == null) return '';
  if (duration.inMinutes < 1) return l.durationUnderMinute;
  if (duration.inMinutes < 60) return l.durationMinutes(duration.inMinutes);
  return l.durationHours(duration.inHours, duration.inMinutes % 60);
}

String kindLabel(AppLocalizations l, ChangeKind kind) => switch (kind) {
      ChangeKind.modified => l.kindModified,
      ChangeKind.added => l.kindAdded,
      ChangeKind.deleted => l.kindDeleted,
      ChangeKind.renamed => l.kindRenamed,
      ChangeKind.untracked => l.kindUntracked,
      ChangeKind.conflicted => l.kindConflicted,
    };

String ciLabel(AppLocalizations l, CiStatus ci) => switch (ci.state) {
      CiState.none => l.ciNone,
      CiState.queued => [l.ciQueued, if (ci.remaining != null) timeLeft(l, ci.remaining!)].join(' · '),
      CiState.running => [l.ciJobs(ci.doneJobs, ci.totalJobs), if (ci.remaining != null) timeLeft(l, ci.remaining!)].join(' · '),
      CiState.success => l.ciPassed(shortDuration(l, ci.duration)),
      CiState.failure => ci.failedJob == null ? l.ciFailed : l.ciFailedIn(ci.failedJob!),
      CiState.cancelled => l.ciCancelled,
    };

String timeLeft(AppLocalizations l, Duration left) =>
    left.inSeconds < 45 ? l.almostDone : l.minutesLeft((left.inSeconds / 60).ceil());

/// 2171 becomes 2k so a count always fits inside a button.
String compactCount(int n) => n < 1000 ? '$n' : '${(n / 1000).round()}k';

/// How long an answer usually takes, so a spinner never looks like nothing is happening.
String providerSpeed(AppLocalizations l, AiProvider provider) => switch (provider) {
      AiProvider.codex => l.speedCodex,
      AiProvider.claudeCode => l.speedClaudeCode,
      _ => l.speedApi,
    };

String operationLabel(RepoOperation operation) => switch (operation) {
      RepoOperation.rebase => 'rebase',
      RepoOperation.merge => 'merge',
      RepoOperation.cherryPick => 'cherry-pick',
      RepoOperation.none => '',
    };

/// An error in the user's language when the AI layer gave it a code, otherwise as git said it.
String errorText(AppLocalizations l, Object error) =>
    error is AiException ? aiText(l, error.kind, error.detail) : error.toString();

/// The first line of an error, short enough for a progress row.
String firstLine(AppLocalizations l, Object error) {
  final text = errorText(l, error);
  final line = text.trim().split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => text);
  return line.length > 140 ? '${line.substring(0, 140)}…' : line;
}

/// What an agent step says: its own words, or the app's wording for the fixed ones.
String agentEventText(AppLocalizations l, AgentEvent event) =>
    event.kind == null ? event.text : aiText(l, event.kind!, event.detail);

String aiText(AppLocalizations l, AiText kind, String detail) => switch (kind) {
      AiText.badKey => l.aiBadKey,
      AiText.keychainFailed => l.aiKeychainFailed(detail),
      AiText.emptyReply => l.aiEmptyReply,
      AiText.cliMissing => l.aiCliMissing(detail),
      AiText.claudeSignedOut => l.aiClaudeSignedOut,
      AiText.timedOut => l.aiTimedOut(detail),
      AiText.cliFailed => l.aiCliFailed(detail),
      AiText.refused => l.aiRefused,
      AiText.noModel => l.aiNoModel,
      AiText.noKey => l.aiNoKey,
      AiText.httpStatus => l.aiHttpStatus(detail),
      AiText.unreachable => l.aiUnreachable(detail),
      AiText.agentOff => l.aiAgentOff,
      AiText.agentStopped => l.aiAgentStopped(detail),
      AiText.agentFinished => l.aiAgentFinished(detail),
    };

String providerLabel(AppLocalizations l, AiProvider provider) => switch (provider) {
      AiProvider.claudeCode => 'Claude Code',
      AiProvider.codex => 'Codex',
      AiProvider.anthropic => 'Anthropic API',
      AiProvider.openai => 'OpenAI API',
      AiProvider.deepseek => 'DeepSeek API',
      AiProvider.gemini => 'Google Gemini API',
      AiProvider.custom => l.providerCustom,
    };

String agentLabel(AppLocalizations l, AgentProvider agent) => switch (agent) {
      AgentProvider.claudeCode => 'Claude Code',
      AgentProvider.codex => 'Codex',
      AgentProvider.off => l.agentOff,
    };

/// Shows a path with the home folder as ~.
String homePath(String path, String home) => path.startsWith(home) ? '~${path.substring(home.length)}' : path;
