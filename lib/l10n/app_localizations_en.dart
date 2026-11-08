// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageEnglish => 'English';

  @override
  String get languageIcelandic => 'Íslenska';

  @override
  String get noCommits => 'no commits';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String hoursAgo(int n) {
    return '$n h ago';
  }

  @override
  String get yesterday => 'yesterday';

  @override
  String daysAgo(int n) {
    return '$n days ago';
  }

  @override
  String get aWeekAgo => 'a week ago';

  @override
  String weeksAgo(int n) {
    return '$n weeks ago';
  }

  @override
  String get durationUnderMinute => '< 1 min';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get kindModified => 'modified';

  @override
  String get kindAdded => 'new';

  @override
  String get kindDeleted => 'deleted';

  @override
  String get kindRenamed => 'renamed';

  @override
  String get kindUntracked => 'untracked';

  @override
  String get kindConflicted => 'conflict';

  @override
  String get ciNone => 'No CI pipeline';

  @override
  String get ciQueued => 'Queued';

  @override
  String ciJobs(int done, int total) {
    return '$done of $total jobs';
  }

  @override
  String ciPassed(String duration) {
    return 'Passed · $duration';
  }

  @override
  String get ciFailed => 'Failed';

  @override
  String ciFailedIn(String job) {
    return 'Failed in $job';
  }

  @override
  String get ciCancelled => 'Cancelled';

  @override
  String get almostDone => 'almost done';

  @override
  String minutesLeft(int n) {
    return '≈ $n min left';
  }

  @override
  String commitsAhead(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n commits to push',
      one: '1 commit to push',
    );
    return '$_temp0';
  }

  @override
  String commitsBehind(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n commits behind the remote',
      one: '1 commit behind the remote',
    );
    return '$_temp0';
  }

  @override
  String fileCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get speedCodex => 'can take up to a minute';

  @override
  String get speedClaudeCode => 'takes a few seconds';

  @override
  String get speedApi => 'takes 1–5 seconds';

  @override
  String get providerCustom => 'OpenAI-compatible API';

  @override
  String get agentOff => 'Off';

  @override
  String get aiBadKey =>
      'The key must not be empty or contain spaces, quotes or backslashes';

  @override
  String aiKeychainFailed(String detail) {
    return 'Could not save the key in the Keychain: $detail';
  }

  @override
  String get aiEmptyReply => 'The AI returned an empty answer';

  @override
  String aiCliMissing(String tool) {
    return '$tool was not found on this Mac';
  }

  @override
  String get aiClaudeSignedOut =>
      'Claude Code is not signed in. Open Settings and click Sign in, or choose another AI.';

  @override
  String aiTimedOut(String tool) {
    return '$tool did not answer within 3 minutes';
  }

  @override
  String aiCliFailed(String detail) {
    return 'The AI could not write a message: $detail';
  }

  @override
  String get aiRefused => 'Claude declined to write this message';

  @override
  String get aiNoModel => 'Choose a model in Settings';

  @override
  String get aiNoKey => 'No API key saved. Add one in Settings.';

  @override
  String aiHttpStatus(String detail) {
    return 'The AI service answered $detail';
  }

  @override
  String aiUnreachable(String host) {
    return 'Cannot reach $host';
  }

  @override
  String get aiAgentOff => 'The AI agent is turned off in Settings';

  @override
  String aiAgentStopped(String detail) {
    return '$detail stopped';
  }

  @override
  String aiAgentFinished(String detail) {
    return '$detail finished';
  }

  @override
  String get cardViewChanges => 'View changes and history';

  @override
  String get cardCommitHint => 'Write a commit message';

  @override
  String get nothingToCommit => 'Nothing to commit';

  @override
  String cardAiWriting(String provider, String speed) {
    return '$provider is writing a message · $speed';
  }

  @override
  String get cardAiWriteTooltip => 'Let AI write the message';

  @override
  String get cardReadingStatus => 'Reading status…';

  @override
  String get cardCleanTree => 'Clean working tree';

  @override
  String cardOperationInProgress(String operation) {
    return 'A $operation is in progress';
  }

  @override
  String get cardNoUpstream => 'No upstream';

  @override
  String cardUpToDate(String upstream) {
    return 'Up to date with $upstream';
  }

  @override
  String get cardNoCommits => 'No commits yet';

  @override
  String get cardFixCi => 'Fix';

  @override
  String get cardFixCiTooltip =>
      'Let AI fix the CI failure, then commit and push';

  @override
  String get cardCiWatching =>
      'Watching CI: you’ll be notified when the run ends';

  @override
  String get cardWatchCi => 'Watch CI';

  @override
  String get cardMenuUseAgent => 'Use AI agent';

  @override
  String get cardMenuUseAgentHint => 'Writes, commits and pushes';

  @override
  String get pullWithRebase => 'Pull with rebase';

  @override
  String get cardMenuRebaseOnMain => 'Rebase on origin/main';

  @override
  String get cardMenuSync => 'Sync (pull and push)';

  @override
  String get cardMenuStash => 'Stash changes';

  @override
  String get cardMenuStashPop => 'Pop stash';

  @override
  String cardMenuContinue(String operation) {
    return 'Continue $operation';
  }

  @override
  String cardMenuAbort(String operation) {
    return 'Abort $operation';
  }

  @override
  String get cardMenuFixCi => 'Fix CI with AI';

  @override
  String get cardMenuOpenCiRun => 'Open CI run';

  @override
  String get openInVsCode => 'Open in VS Code';

  @override
  String get cardMenuOpenFinder => 'Show in Finder';

  @override
  String get cardMenuOpenTerminal => 'Open in Terminal';

  @override
  String get cardMenuChangeIcon => 'Change icon…';

  @override
  String get cardMenuDefaultIcon => 'Use default icon';

  @override
  String get cardMenuHideRepo => 'Hide repo';

  @override
  String get cardMenuMore => 'More actions';

  @override
  String get cardMenuImages => 'Images';

  @override
  String get cardChoose => 'Choose';

  @override
  String get cardFolderWatching => 'Watching';

  @override
  String cardRepoCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n repos',
      one: '1 repo',
    );
    return '$_temp0';
  }

  @override
  String get cardFolderRecent => 'Recent folders';

  @override
  String get cardFolderHidden => 'Hidden repos · click to show again';

  @override
  String get cardFolderRecursive => 'Search all subfolders';

  @override
  String get cardFolderChoose => 'Choose folder…';

  @override
  String get repoBack => 'Back (⌘[)';

  @override
  String repoOperationInProgress(String operation) {
    return '$operation in progress';
  }

  @override
  String get repoContinue => 'Continue';

  @override
  String get repoAbort => 'Abort';

  @override
  String get fetchDone => 'Fetch complete';

  @override
  String repoTabChanges(int count) {
    return 'Changes  $count';
  }

  @override
  String get repoTabHistory => 'History';

  @override
  String get repoClean => 'The working tree is clean.';

  @override
  String repoCleanWithAhead(String ahead) {
    return 'The working tree is clean, with $ahead.';
  }

  @override
  String get repoViewHistory => 'View history';

  @override
  String repoSelectedCount(int selected, int total) {
    return '$selected of $total selected';
  }

  @override
  String get repoDiscardChanges => 'Discard changes';

  @override
  String get repoShowInFinder => 'Show in Finder';

  @override
  String get repoDiscardChangesTitle => 'Discard changes?';

  @override
  String get repoDiscard => 'Discard';

  @override
  String repoDiscardNewFileBody(String path) {
    return '$path is a new file. It will be moved to the Trash, where you can still get it back.';
  }

  @override
  String repoDiscardChangesBody(String path) {
    return 'Your changes to $path will be lost. This cannot be undone.';
  }

  @override
  String repoChangesDiscarded(String name) {
    return 'Discarded changes to $name';
  }

  @override
  String get repoCommitMessageHint => 'Commit message';

  @override
  String get repoWriteWithAi => 'Write with AI';

  @override
  String get repoCommitAndPush => 'Commit and push';

  @override
  String repoCommittedAndPushed(String summary) {
    return '$summary and pushed';
  }

  @override
  String get repoNoCommitsYet => 'No commits yet';

  @override
  String get repoNotPushed => 'Not pushed';

  @override
  String get repoSelectFile => 'Select a file';

  @override
  String get repoSelectFileHint => 'Click a file to see what changed in it.';

  @override
  String get repoNoticeBinary => 'Binary file: the changes cannot be shown';

  @override
  String get repoNoticeMissing => 'The file no longer exists';

  @override
  String get repoNoticeDirectory => 'This is a folder, often another git repo';

  @override
  String get repoNoticeTooLarge => 'The file is too large to show';

  @override
  String get repoNoticeEmpty =>
      'No content changes, for example only permissions changed';

  @override
  String repoDiffTruncated(int n) {
    return 'This diff is too long. Only the first $n lines are shown.';
  }

  @override
  String repoDonutFiles(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'files',
      one: 'file',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get close => 'Close';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Applies to the whole app right away.';

  @override
  String get settingsCommitAiTitle => 'AI for commit messages';

  @override
  String get settingsCommitAiSubtitle =>
      'Used by the AI button on each card, AI messages and the AI helper.';

  @override
  String get settingsTest => 'Test';

  @override
  String settingsWaiting(int seconds, String speed) {
    return 'Waiting for a reply · $seconds s · $speed';
  }

  @override
  String settingsTestWorks(String message) {
    return 'It works: $message';
  }

  @override
  String get settingsAgentTitle => 'AI agent that fixes problems';

  @override
  String get settingsAgentSubtitle =>
      'Runs git in the repo by itself when a commit, rebase or push stops: it resolves conflicts and finishes the job. Uses a Claude Code or Codex subscription, because an API key alone cannot run git.';

  @override
  String get settingsHiddenTitle => 'Hidden repos';

  @override
  String get settingsHiddenSubtitle =>
      'Hidden repos are not shown and are left out of Commit all, Push all and the AI helper.';

  @override
  String get settingsNoHidden =>
      'No hidden repos. Hide one from More actions on its card.';

  @override
  String get settingsShowAgain => 'Show again';

  @override
  String settingsUsesSubscription(String speed) {
    return 'Uses your subscription, $speed.';
  }

  @override
  String settingsSignedIn(String name) {
    return '$name: signed in';
  }

  @override
  String settingsSignedOut(String name) {
    return '$name: not signed in';
  }

  @override
  String get settingsSignIn => 'Sign in';

  @override
  String settingsSignInTooltip(String command) {
    return 'Opens Terminal and runs $command';
  }

  @override
  String get settingsCheckAgain => 'Check again';

  @override
  String get settingsModel => 'Model';

  @override
  String settingsModelExample(String model) {
    return 'e.g. $model';
  }

  @override
  String get settingsBaseUrl => 'Base URL';

  @override
  String get settingsApiKey => 'API key';

  @override
  String get settingsKeySavedHint =>
      'Saved in the Keychain · type a new key to replace it';

  @override
  String get settingsKeyPasteHint => 'Paste the key here';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsKeySaved => 'Key saved in the macOS Keychain';

  @override
  String get settingsDelete => 'Delete';

  @override
  String appCiNotification(String repo, String status) {
    return '$repo: CI $status';
  }

  @override
  String get appWriteMessageFirst =>
      'Write a commit message first, or let AI write one.';

  @override
  String appCommitted(String hash, String repo) {
    return 'Committed $hash to $repo';
  }

  @override
  String get appBusyContinue => 'Continuing…';

  @override
  String get appBusyAbort => 'Aborting…';

  @override
  String get appBusyDiscard => 'Discarding…';

  @override
  String appSkippedNoMessage(String repo) {
    return '$repo: skipped, no message';
  }

  @override
  String appCommittedRepo(String repo) {
    return '$repo: committed';
  }

  @override
  String appPushedRepo(String repo) {
    return '$repo: pushed';
  }

  @override
  String get topSettingsTooltip => 'Settings: AI and hidden repos';

  @override
  String get topRefreshTooltip => 'Refresh (⌘R)';

  @override
  String topFixAllCi(int n) {
    return 'Fix all CI · $n';
  }

  @override
  String get topFixAllCiTooltip =>
      'An AI agent fixes every failed CI, one repo at a time';

  @override
  String get topAiHelperTooltip =>
      'Write messages, commit and push every repo, and fix problems';

  @override
  String get topAiMessages => 'AI messages';

  @override
  String get topAiMessagesTooltip =>
      'Let AI write commit messages for every repo with changes';

  @override
  String get topCommitAll => 'Commit all';

  @override
  String get topPushAll => 'Push all';

  @override
  String get topFetchAll => 'Fetch all';

  @override
  String topWithChanges(int n) {
    return '$n with changes';
  }

  @override
  String topWaitingPush(int n) {
    return '$n to push';
  }

  @override
  String topCiRunning(int n) {
    return '$n CI running';
  }

  @override
  String topCiFailed(int n) {
    return '$n CI failed';
  }

  @override
  String topPushRepos(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Push $n repos',
      one: 'Push 1 repo',
    );
    return '$_temp0';
  }

  @override
  String get topScanning => 'Looking for git repos…';

  @override
  String get topNoRepos => 'No git repos found';

  @override
  String get topAllGood => 'All good';

  @override
  String topNothingToShip(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n repos · nothing to commit or push',
      one: '1 repo · nothing to commit or push',
    );
    return '$_temp0';
  }

  @override
  String topShowAll(int n) {
    return 'Show all $n';
  }

  @override
  String get topStackAgain => 'Stack again';

  @override
  String get topErrorTitle => 'That didn\'t work';

  @override
  String get topCancel => 'Cancel';

  @override
  String get topNothingToCommitOrPush => 'Nothing to commit or push';

  @override
  String topProviderSignedOut(String provider) {
    return '$provider is not signed in. Open Settings and sign in, or choose an API key.';
  }

  @override
  String topAiAgentFor(String repo) {
    return 'AI agent for $repo';
  }

  @override
  String get topStart => 'Start';

  @override
  String topAiHelperIntro(String agent) {
    return 'AI writes commit messages, commits every change, fetches and rebases when needed, and pushes. If something gets stuck, $agent takes over and fixes it.';
  }

  @override
  String get topNoAgentReady =>
      'No AI agent is ready. Open Settings, choose Claude Code or Codex, and sign in.';

  @override
  String topFixCiIn(String repo) {
    return 'Fix CI in $repo';
  }

  @override
  String topFixAllCiRepos(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Fix all CI · $n repos',
      one: 'Fix all CI · 1 repo',
    );
    return '$_temp0';
  }

  @override
  String get topFixCi => 'Fix CI';

  @override
  String topFixRepos(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Fix $n repos',
      one: 'Fix 1 repo',
    );
    return '$_temp0';
  }

  @override
  String topFixCiIntro(String agent) {
    return '$agent reads the error from each CI run, fixes the code, commits and pushes, one repo at a time. It never uses --force or --no-verify and never turns off tests. If the error is not in the code (a missing secret, for example), it changes nothing and explains why.';
  }

  @override
  String topHelperWorkingOn(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'working on $n repos…',
      one: 'working on 1 repo…',
    );
    return '$_temp0';
  }

  @override
  String topHelperDone(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Done · $done of $total repos finished',
      one: 'Done · $done of 1 repo finished',
    );
    return '$_temp0';
  }

  @override
  String get topHelperWritingMessage => 'Write commit message';

  @override
  String topHelperCommitFiles(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Commit $n files',
      one: 'Commit 1 file',
    );
    return '$_temp0';
  }

  @override
  String topHelperPushTo(String remote) {
    return 'Push to $remote';
  }

  @override
  String topHelperFixingCiIn(String repo) {
    return 'fixing CI in $repo…';
  }

  @override
  String topHelperFixingCiRepos(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'fixing CI in $n repos…',
      one: 'fixing CI in 1 repo…',
    );
    return '$_temp0';
  }

  @override
  String topHelperCiDone(int fixed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Done · CI fixed and pushed in $fixed of $total repos',
      one: 'Done · CI fixed and pushed in $fixed of 1 repo',
    );
    return '$_temp0';
  }

  @override
  String get topBusyFixingCi => 'Fixing CI…';

  @override
  String get topCiFixFailed => 'Could not fix CI';

  @override
  String get topHelperFetchingCiLog => 'Get the error from the CI run';

  @override
  String topAgentChangedNotPushed(String text) {
    return 'Changed but not pushed: $text';
  }

  @override
  String topAgentNoChange(String text) {
    return 'Nothing changed: $text';
  }

  @override
  String get topFixAwaitingPush => 'Fix waiting to be pushed';

  @override
  String get topNoChangeSeeAgent =>
      'Nothing changed · see the agent\'s explanation';

  @override
  String get topFixedWatchingCi => 'Fixed and pushed · watching the new CI run';

  @override
  String topHelperProblem(String error) {
    return 'Problem: $error. An AI agent is taking over';
  }

  @override
  String topAgentNotFinished(String text) {
    return 'Not finished: $text';
  }

  @override
  String topAgentWorking(String agent) {
    return '$agent is working…';
  }

  @override
  String get topAgentFinished => 'AI agent finished';

  @override
  String topAgentCouldNotStart(String error) {
    return 'The AI agent could not start: $error';
  }
}
