import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_is.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('is'),
  ];

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageIcelandic.
  ///
  /// In en, this message translates to:
  /// **'Íslenska'**
  String get languageIcelandic;

  /// No description provided for @noCommits.
  ///
  /// In en, this message translates to:
  /// **'no commits'**
  String get noCommits;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String minutesAgo(int n);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String hoursAgo(int n);

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} days ago'**
  String daysAgo(int n);

  /// No description provided for @aWeekAgo.
  ///
  /// In en, this message translates to:
  /// **'a week ago'**
  String get aWeekAgo;

  /// No description provided for @weeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} weeks ago'**
  String weeksAgo(int n);

  /// No description provided for @durationUnderMinute.
  ///
  /// In en, this message translates to:
  /// **'< 1 min'**
  String get durationUnderMinute;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHours(int hours, int minutes);

  /// No description provided for @kindModified.
  ///
  /// In en, this message translates to:
  /// **'modified'**
  String get kindModified;

  /// No description provided for @kindAdded.
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get kindAdded;

  /// No description provided for @kindDeleted.
  ///
  /// In en, this message translates to:
  /// **'deleted'**
  String get kindDeleted;

  /// No description provided for @kindRenamed.
  ///
  /// In en, this message translates to:
  /// **'renamed'**
  String get kindRenamed;

  /// No description provided for @kindUntracked.
  ///
  /// In en, this message translates to:
  /// **'untracked'**
  String get kindUntracked;

  /// No description provided for @kindConflicted.
  ///
  /// In en, this message translates to:
  /// **'conflict'**
  String get kindConflicted;

  /// No description provided for @ciNone.
  ///
  /// In en, this message translates to:
  /// **'No CI pipeline'**
  String get ciNone;

  /// No description provided for @ciQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get ciQueued;

  /// No description provided for @ciJobs.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} jobs'**
  String ciJobs(int done, int total);

  /// No description provided for @ciPassed.
  ///
  /// In en, this message translates to:
  /// **'Passed · {duration}'**
  String ciPassed(String duration);

  /// No description provided for @ciFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get ciFailed;

  /// No description provided for @ciFailedIn.
  ///
  /// In en, this message translates to:
  /// **'Failed in {job}'**
  String ciFailedIn(String job);

  /// No description provided for @ciCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get ciCancelled;

  /// No description provided for @almostDone.
  ///
  /// In en, this message translates to:
  /// **'almost done'**
  String get almostDone;

  /// No description provided for @minutesLeft.
  ///
  /// In en, this message translates to:
  /// **'≈ {n} min left'**
  String minutesLeft(int n);

  /// No description provided for @commitsAhead.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 commit to push} other{{n} commits to push}}'**
  String commitsAhead(int n);

  /// No description provided for @commitsBehind.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 commit behind the remote} other{{n} commits behind the remote}}'**
  String commitsBehind(int n);

  /// No description provided for @fileCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 file} other{{n} files}}'**
  String fileCount(int n);

  /// No description provided for @speedCodex.
  ///
  /// In en, this message translates to:
  /// **'can take up to a minute'**
  String get speedCodex;

  /// No description provided for @speedClaudeCode.
  ///
  /// In en, this message translates to:
  /// **'takes a few seconds'**
  String get speedClaudeCode;

  /// No description provided for @speedApi.
  ///
  /// In en, this message translates to:
  /// **'takes 1–5 seconds'**
  String get speedApi;

  /// No description provided for @providerCustom.
  ///
  /// In en, this message translates to:
  /// **'OpenAI-compatible API'**
  String get providerCustom;

  /// No description provided for @agentOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get agentOff;

  /// No description provided for @aiBadKey.
  ///
  /// In en, this message translates to:
  /// **'The key must not be empty or contain spaces, quotes or backslashes'**
  String get aiBadKey;

  /// No description provided for @aiKeychainFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the key in the Keychain: {detail}'**
  String aiKeychainFailed(String detail);

  /// No description provided for @aiEmptyReply.
  ///
  /// In en, this message translates to:
  /// **'The AI returned an empty answer'**
  String get aiEmptyReply;

  /// No description provided for @aiCliMissing.
  ///
  /// In en, this message translates to:
  /// **'{tool} was not found on this Mac'**
  String aiCliMissing(String tool);

  /// No description provided for @aiClaudeSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Claude Code is not signed in. Open Settings and click Sign in, or choose another AI.'**
  String get aiClaudeSignedOut;

  /// No description provided for @aiTimedOut.
  ///
  /// In en, this message translates to:
  /// **'{tool} did not answer within 3 minutes'**
  String aiTimedOut(String tool);

  /// No description provided for @aiCliFailed.
  ///
  /// In en, this message translates to:
  /// **'The AI could not write a message: {detail}'**
  String aiCliFailed(String detail);

  /// No description provided for @aiRefused.
  ///
  /// In en, this message translates to:
  /// **'Claude declined to write this message'**
  String get aiRefused;

  /// No description provided for @aiNoModel.
  ///
  /// In en, this message translates to:
  /// **'Choose a model in Settings'**
  String get aiNoModel;

  /// No description provided for @aiNoKey.
  ///
  /// In en, this message translates to:
  /// **'No API key saved. Add one in Settings.'**
  String get aiNoKey;

  /// No description provided for @aiHttpStatus.
  ///
  /// In en, this message translates to:
  /// **'The AI service answered {detail}'**
  String aiHttpStatus(String detail);

  /// No description provided for @aiUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach {host}'**
  String aiUnreachable(String host);

  /// No description provided for @aiAgentOff.
  ///
  /// In en, this message translates to:
  /// **'The AI agent is turned off in Settings'**
  String get aiAgentOff;

  /// No description provided for @aiAgentStopped.
  ///
  /// In en, this message translates to:
  /// **'{detail} stopped'**
  String aiAgentStopped(String detail);

  /// No description provided for @aiAgentFinished.
  ///
  /// In en, this message translates to:
  /// **'{detail} finished'**
  String aiAgentFinished(String detail);

  /// No description provided for @cardViewChanges.
  ///
  /// In en, this message translates to:
  /// **'View changes and history'**
  String get cardViewChanges;

  /// No description provided for @cardCommitHint.
  ///
  /// In en, this message translates to:
  /// **'Write a commit message'**
  String get cardCommitHint;

  /// No description provided for @nothingToCommit.
  ///
  /// In en, this message translates to:
  /// **'Nothing to commit'**
  String get nothingToCommit;

  /// No description provided for @cardAiWriting.
  ///
  /// In en, this message translates to:
  /// **'{provider} is writing a message · {speed}'**
  String cardAiWriting(String provider, String speed);

  /// No description provided for @cardAiWriteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Let AI write the message'**
  String get cardAiWriteTooltip;

  /// No description provided for @cardReadingStatus.
  ///
  /// In en, this message translates to:
  /// **'Reading status…'**
  String get cardReadingStatus;

  /// No description provided for @cardCleanTree.
  ///
  /// In en, this message translates to:
  /// **'Clean working tree'**
  String get cardCleanTree;

  /// No description provided for @cardOperationInProgress.
  ///
  /// In en, this message translates to:
  /// **'A {operation} is in progress'**
  String cardOperationInProgress(String operation);

  /// No description provided for @cardNoUpstream.
  ///
  /// In en, this message translates to:
  /// **'No upstream'**
  String get cardNoUpstream;

  /// No description provided for @cardUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date with {upstream}'**
  String cardUpToDate(String upstream);

  /// No description provided for @cardNoCommits.
  ///
  /// In en, this message translates to:
  /// **'No commits yet'**
  String get cardNoCommits;

  /// No description provided for @cardFixCi.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get cardFixCi;

  /// No description provided for @cardFixCiTooltip.
  ///
  /// In en, this message translates to:
  /// **'Let AI fix the CI failure, then commit and push'**
  String get cardFixCiTooltip;

  /// No description provided for @cardCiWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching CI: you’ll be notified when the run ends'**
  String get cardCiWatching;

  /// No description provided for @cardWatchCi.
  ///
  /// In en, this message translates to:
  /// **'Watch CI'**
  String get cardWatchCi;

  /// No description provided for @cardMenuUseAgent.
  ///
  /// In en, this message translates to:
  /// **'Use AI agent'**
  String get cardMenuUseAgent;

  /// No description provided for @cardMenuUseAgentHint.
  ///
  /// In en, this message translates to:
  /// **'Writes, commits and pushes'**
  String get cardMenuUseAgentHint;

  /// No description provided for @pullWithRebase.
  ///
  /// In en, this message translates to:
  /// **'Pull with rebase'**
  String get pullWithRebase;

  /// No description provided for @cardMenuRebaseOnMain.
  ///
  /// In en, this message translates to:
  /// **'Rebase on origin/main'**
  String get cardMenuRebaseOnMain;

  /// No description provided for @cardMenuSync.
  ///
  /// In en, this message translates to:
  /// **'Sync (pull and push)'**
  String get cardMenuSync;

  /// No description provided for @cardMenuStash.
  ///
  /// In en, this message translates to:
  /// **'Stash changes'**
  String get cardMenuStash;

  /// No description provided for @cardMenuStashPop.
  ///
  /// In en, this message translates to:
  /// **'Pop stash'**
  String get cardMenuStashPop;

  /// No description provided for @cardMenuContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue {operation}'**
  String cardMenuContinue(String operation);

  /// No description provided for @cardMenuAbort.
  ///
  /// In en, this message translates to:
  /// **'Abort {operation}'**
  String cardMenuAbort(String operation);

  /// No description provided for @cardMenuFixCi.
  ///
  /// In en, this message translates to:
  /// **'Fix CI with AI'**
  String get cardMenuFixCi;

  /// No description provided for @cardMenuOpenCiRun.
  ///
  /// In en, this message translates to:
  /// **'Open CI run'**
  String get cardMenuOpenCiRun;

  /// No description provided for @openInVsCode.
  ///
  /// In en, this message translates to:
  /// **'Open in VS Code'**
  String get openInVsCode;

  /// No description provided for @cardMenuOpenFinder.
  ///
  /// In en, this message translates to:
  /// **'Show in Finder'**
  String get cardMenuOpenFinder;

  /// No description provided for @cardMenuOpenTerminal.
  ///
  /// In en, this message translates to:
  /// **'Open in Terminal'**
  String get cardMenuOpenTerminal;

  /// No description provided for @cardMenuChangeIcon.
  ///
  /// In en, this message translates to:
  /// **'Change icon…'**
  String get cardMenuChangeIcon;

  /// No description provided for @cardMenuDefaultIcon.
  ///
  /// In en, this message translates to:
  /// **'Use default icon'**
  String get cardMenuDefaultIcon;

  /// No description provided for @cardMenuHideRepo.
  ///
  /// In en, this message translates to:
  /// **'Hide repo'**
  String get cardMenuHideRepo;

  /// No description provided for @cardMenuMore.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get cardMenuMore;

  /// No description provided for @cardMenuImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get cardMenuImages;

  /// No description provided for @cardChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get cardChoose;

  /// No description provided for @cardFolderWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get cardFolderWatching;

  /// No description provided for @cardRepoCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 repo} other{{n} repos}}'**
  String cardRepoCount(int n);

  /// No description provided for @cardFolderRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent folders'**
  String get cardFolderRecent;

  /// No description provided for @cardFolderHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden repos · click to show again'**
  String get cardFolderHidden;

  /// No description provided for @cardFolderRecursive.
  ///
  /// In en, this message translates to:
  /// **'Search all subfolders'**
  String get cardFolderRecursive;

  /// No description provided for @cardFolderChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose folder…'**
  String get cardFolderChoose;

  /// No description provided for @repoBack.
  ///
  /// In en, this message translates to:
  /// **'Back (⌘[)'**
  String get repoBack;

  /// No description provided for @repoOperationInProgress.
  ///
  /// In en, this message translates to:
  /// **'{operation} in progress'**
  String repoOperationInProgress(String operation);

  /// No description provided for @repoContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get repoContinue;

  /// No description provided for @repoAbort.
  ///
  /// In en, this message translates to:
  /// **'Abort'**
  String get repoAbort;

  /// No description provided for @fetchDone.
  ///
  /// In en, this message translates to:
  /// **'Fetch complete'**
  String get fetchDone;

  /// No description provided for @repoTabChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes  {count}'**
  String repoTabChanges(int count);

  /// No description provided for @repoTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get repoTabHistory;

  /// No description provided for @repoClean.
  ///
  /// In en, this message translates to:
  /// **'The working tree is clean.'**
  String get repoClean;

  /// No description provided for @repoCleanWithAhead.
  ///
  /// In en, this message translates to:
  /// **'The working tree is clean, with {ahead}.'**
  String repoCleanWithAhead(String ahead);

  /// No description provided for @repoViewHistory.
  ///
  /// In en, this message translates to:
  /// **'View history'**
  String get repoViewHistory;

  /// No description provided for @repoSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} selected'**
  String repoSelectedCount(int selected, int total);

  /// No description provided for @repoDiscardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get repoDiscardChanges;

  /// No description provided for @repoShowInFinder.
  ///
  /// In en, this message translates to:
  /// **'Show in Finder'**
  String get repoShowInFinder;

  /// No description provided for @repoDiscardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get repoDiscardChangesTitle;

  /// No description provided for @repoDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get repoDiscard;

  /// No description provided for @repoDiscardNewFileBody.
  ///
  /// In en, this message translates to:
  /// **'{path} is a new file. It will be moved to the Trash, where you can still get it back.'**
  String repoDiscardNewFileBody(String path);

  /// No description provided for @repoDiscardChangesBody.
  ///
  /// In en, this message translates to:
  /// **'Your changes to {path} will be lost. This cannot be undone.'**
  String repoDiscardChangesBody(String path);

  /// No description provided for @repoChangesDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Discarded changes to {name}'**
  String repoChangesDiscarded(String name);

  /// No description provided for @repoCommitMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Commit message'**
  String get repoCommitMessageHint;

  /// No description provided for @repoWriteWithAi.
  ///
  /// In en, this message translates to:
  /// **'Write with AI'**
  String get repoWriteWithAi;

  /// No description provided for @repoCommitAndPush.
  ///
  /// In en, this message translates to:
  /// **'Commit and push'**
  String get repoCommitAndPush;

  /// No description provided for @repoCommittedAndPushed.
  ///
  /// In en, this message translates to:
  /// **'{summary} and pushed'**
  String repoCommittedAndPushed(String summary);

  /// No description provided for @repoNoCommitsYet.
  ///
  /// In en, this message translates to:
  /// **'No commits yet'**
  String get repoNoCommitsYet;

  /// No description provided for @repoNotPushed.
  ///
  /// In en, this message translates to:
  /// **'Not pushed'**
  String get repoNotPushed;

  /// No description provided for @repoSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Select a file'**
  String get repoSelectFile;

  /// No description provided for @repoSelectFileHint.
  ///
  /// In en, this message translates to:
  /// **'Click a file to see what changed in it.'**
  String get repoSelectFileHint;

  /// No description provided for @repoNoticeBinary.
  ///
  /// In en, this message translates to:
  /// **'Binary file: the changes cannot be shown'**
  String get repoNoticeBinary;

  /// No description provided for @repoNoticeMissing.
  ///
  /// In en, this message translates to:
  /// **'The file no longer exists'**
  String get repoNoticeMissing;

  /// No description provided for @repoNoticeDirectory.
  ///
  /// In en, this message translates to:
  /// **'This is a folder, often another git repo'**
  String get repoNoticeDirectory;

  /// No description provided for @repoNoticeTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is too large to show'**
  String get repoNoticeTooLarge;

  /// No description provided for @repoNoticeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No content changes, for example only permissions changed'**
  String get repoNoticeEmpty;

  /// No description provided for @repoDiffTruncated.
  ///
  /// In en, this message translates to:
  /// **'This diff is too long. Only the first {n} lines are shown.'**
  String repoDiffTruncated(int n);

  /// No description provided for @repoDonutFiles.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{file} other{files}}'**
  String repoDonutFiles(int n);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Applies to the whole app right away.'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsCommitAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI for commit messages'**
  String get settingsCommitAiTitle;

  /// No description provided for @settingsCommitAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used by the AI button on each card, AI messages and the AI helper.'**
  String get settingsCommitAiSubtitle;

  /// No description provided for @settingsTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get settingsTest;

  /// No description provided for @settingsWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a reply · {seconds} s · {speed}'**
  String settingsWaiting(int seconds, String speed);

  /// No description provided for @settingsTestWorks.
  ///
  /// In en, this message translates to:
  /// **'It works: {message}'**
  String settingsTestWorks(String message);

  /// No description provided for @settingsAgentTitle.
  ///
  /// In en, this message translates to:
  /// **'AI agent that fixes problems'**
  String get settingsAgentTitle;

  /// No description provided for @settingsAgentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Runs git in the repo by itself when a commit, rebase or push stops: it resolves conflicts and finishes the job. Uses a Claude Code or Codex subscription, because an API key alone cannot run git.'**
  String get settingsAgentSubtitle;

  /// No description provided for @settingsHiddenTitle.
  ///
  /// In en, this message translates to:
  /// **'Hidden repos'**
  String get settingsHiddenTitle;

  /// No description provided for @settingsHiddenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hidden repos are not shown and are left out of Commit all, Push all and the AI helper.'**
  String get settingsHiddenSubtitle;

  /// No description provided for @settingsNoHidden.
  ///
  /// In en, this message translates to:
  /// **'No hidden repos. Hide one from More actions on its card.'**
  String get settingsNoHidden;

  /// No description provided for @settingsShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get settingsShowAgain;

  /// No description provided for @settingsUsesSubscription.
  ///
  /// In en, this message translates to:
  /// **'Uses your subscription, {speed}.'**
  String settingsUsesSubscription(String speed);

  /// No description provided for @settingsSignedIn.
  ///
  /// In en, this message translates to:
  /// **'{name}: signed in'**
  String settingsSignedIn(String name);

  /// No description provided for @settingsSignedOut.
  ///
  /// In en, this message translates to:
  /// **'{name}: not signed in'**
  String settingsSignedOut(String name);

  /// No description provided for @settingsSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get settingsSignIn;

  /// No description provided for @settingsSignInTooltip.
  ///
  /// In en, this message translates to:
  /// **'Opens Terminal and runs {command}'**
  String settingsSignInTooltip(String command);

  /// No description provided for @settingsCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get settingsCheckAgain;

  /// No description provided for @settingsModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get settingsModel;

  /// No description provided for @settingsModelExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. {model}'**
  String settingsModelExample(String model);

  /// No description provided for @settingsBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get settingsBaseUrl;

  /// No description provided for @settingsApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get settingsApiKey;

  /// No description provided for @settingsKeySavedHint.
  ///
  /// In en, this message translates to:
  /// **'Saved in the Keychain · type a new key to replace it'**
  String get settingsKeySavedHint;

  /// No description provided for @settingsKeyPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the key here'**
  String get settingsKeyPasteHint;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsKeySaved.
  ///
  /// In en, this message translates to:
  /// **'Key saved in the macOS Keychain'**
  String get settingsKeySaved;

  /// No description provided for @settingsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDelete;

  /// No description provided for @appCiNotification.
  ///
  /// In en, this message translates to:
  /// **'{repo}: CI {status}'**
  String appCiNotification(String repo, String status);

  /// No description provided for @appWriteMessageFirst.
  ///
  /// In en, this message translates to:
  /// **'Write a commit message first, or let AI write one.'**
  String get appWriteMessageFirst;

  /// No description provided for @appCommitted.
  ///
  /// In en, this message translates to:
  /// **'Committed {hash} to {repo}'**
  String appCommitted(String hash, String repo);

  /// No description provided for @appBusyContinue.
  ///
  /// In en, this message translates to:
  /// **'Continuing…'**
  String get appBusyContinue;

  /// No description provided for @appBusyAbort.
  ///
  /// In en, this message translates to:
  /// **'Aborting…'**
  String get appBusyAbort;

  /// No description provided for @appBusyDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discarding…'**
  String get appBusyDiscard;

  /// No description provided for @appSkippedNoMessage.
  ///
  /// In en, this message translates to:
  /// **'{repo}: skipped, no message'**
  String appSkippedNoMessage(String repo);

  /// No description provided for @appCommittedRepo.
  ///
  /// In en, this message translates to:
  /// **'{repo}: committed'**
  String appCommittedRepo(String repo);

  /// No description provided for @appPushedRepo.
  ///
  /// In en, this message translates to:
  /// **'{repo}: pushed'**
  String appPushedRepo(String repo);

  /// No description provided for @topSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings: AI and hidden repos'**
  String get topSettingsTooltip;

  /// No description provided for @topRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh (⌘R)'**
  String get topRefreshTooltip;

  /// No description provided for @topFixAllCi.
  ///
  /// In en, this message translates to:
  /// **'Fix all CI · {n}'**
  String topFixAllCi(int n);

  /// No description provided for @topFixAllCiTooltip.
  ///
  /// In en, this message translates to:
  /// **'An AI agent fixes every failed CI, one repo at a time'**
  String get topFixAllCiTooltip;

  /// No description provided for @topAiHelperTooltip.
  ///
  /// In en, this message translates to:
  /// **'Write messages, commit and push every repo, and fix problems'**
  String get topAiHelperTooltip;

  /// No description provided for @topAiMessages.
  ///
  /// In en, this message translates to:
  /// **'AI messages'**
  String get topAiMessages;

  /// No description provided for @topAiMessagesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Let AI write commit messages for every repo with changes'**
  String get topAiMessagesTooltip;

  /// No description provided for @topCommitAll.
  ///
  /// In en, this message translates to:
  /// **'Commit all'**
  String get topCommitAll;

  /// No description provided for @topPushAll.
  ///
  /// In en, this message translates to:
  /// **'Push all'**
  String get topPushAll;

  /// No description provided for @topFetchAll.
  ///
  /// In en, this message translates to:
  /// **'Fetch all'**
  String get topFetchAll;

  /// No description provided for @topWithChanges.
  ///
  /// In en, this message translates to:
  /// **'{n} with changes'**
  String topWithChanges(int n);

  /// No description provided for @topWaitingPush.
  ///
  /// In en, this message translates to:
  /// **'{n} to push'**
  String topWaitingPush(int n);

  /// No description provided for @topCiRunning.
  ///
  /// In en, this message translates to:
  /// **'{n} CI running'**
  String topCiRunning(int n);

  /// No description provided for @topCiFailed.
  ///
  /// In en, this message translates to:
  /// **'{n} CI failed'**
  String topCiFailed(int n);

  /// No description provided for @topPushRepos.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Push 1 repo} other{Push {n} repos}}'**
  String topPushRepos(int n);

  /// No description provided for @topScanning.
  ///
  /// In en, this message translates to:
  /// **'Looking for git repos…'**
  String get topScanning;

  /// No description provided for @topNoRepos.
  ///
  /// In en, this message translates to:
  /// **'No git repos found'**
  String get topNoRepos;

  /// No description provided for @topAllGood.
  ///
  /// In en, this message translates to:
  /// **'All good'**
  String get topAllGood;

  /// No description provided for @topNothingToShip.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 repo · nothing to commit or push} other{{n} repos · nothing to commit or push}}'**
  String topNothingToShip(int n);

  /// No description provided for @topShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all {n}'**
  String topShowAll(int n);

  /// No description provided for @topStackAgain.
  ///
  /// In en, this message translates to:
  /// **'Stack again'**
  String get topStackAgain;

  /// No description provided for @topErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work'**
  String get topErrorTitle;

  /// No description provided for @topCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get topCancel;

  /// No description provided for @topNothingToCommitOrPush.
  ///
  /// In en, this message translates to:
  /// **'Nothing to commit or push'**
  String get topNothingToCommitOrPush;

  /// No description provided for @topProviderSignedOut.
  ///
  /// In en, this message translates to:
  /// **'{provider} is not signed in. Open Settings and sign in, or choose an API key.'**
  String topProviderSignedOut(String provider);

  /// No description provided for @topAiAgentFor.
  ///
  /// In en, this message translates to:
  /// **'AI agent for {repo}'**
  String topAiAgentFor(String repo);

  /// No description provided for @topStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get topStart;

  /// No description provided for @topAiHelperIntro.
  ///
  /// In en, this message translates to:
  /// **'AI writes commit messages, commits every change, fetches and rebases when needed, and pushes. If something gets stuck, {agent} takes over and fixes it.'**
  String topAiHelperIntro(String agent);

  /// No description provided for @topNoAgentReady.
  ///
  /// In en, this message translates to:
  /// **'No AI agent is ready. Open Settings, choose Claude Code or Codex, and sign in.'**
  String get topNoAgentReady;

  /// No description provided for @topFixCiIn.
  ///
  /// In en, this message translates to:
  /// **'Fix CI in {repo}'**
  String topFixCiIn(String repo);

  /// No description provided for @topFixAllCiRepos.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Fix all CI · 1 repo} other{Fix all CI · {n} repos}}'**
  String topFixAllCiRepos(int n);

  /// No description provided for @topFixCi.
  ///
  /// In en, this message translates to:
  /// **'Fix CI'**
  String get topFixCi;

  /// No description provided for @topFixRepos.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Fix 1 repo} other{Fix {n} repos}}'**
  String topFixRepos(int n);

  /// No description provided for @topFixCiIntro.
  ///
  /// In en, this message translates to:
  /// **'{agent} reads the error from each CI run, fixes the code, commits and pushes, one repo at a time. It never uses --force or --no-verify and never turns off tests. If the error is not in the code (a missing secret, for example), it changes nothing and explains why.'**
  String topFixCiIntro(String agent);

  /// No description provided for @topHelperWorkingOn.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{working on 1 repo…} other{working on {n} repos…}}'**
  String topHelperWorkingOn(int n);

  /// No description provided for @topHelperDone.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{Done · {done} of 1 repo finished} other{Done · {done} of {total} repos finished}}'**
  String topHelperDone(int done, int total);

  /// No description provided for @topHelperWritingMessage.
  ///
  /// In en, this message translates to:
  /// **'Write commit message'**
  String get topHelperWritingMessage;

  /// No description provided for @topHelperCommitFiles.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Commit 1 file} other{Commit {n} files}}'**
  String topHelperCommitFiles(int n);

  /// No description provided for @topHelperPushTo.
  ///
  /// In en, this message translates to:
  /// **'Push to {remote}'**
  String topHelperPushTo(String remote);

  /// No description provided for @topHelperFixingCiIn.
  ///
  /// In en, this message translates to:
  /// **'fixing CI in {repo}…'**
  String topHelperFixingCiIn(String repo);

  /// No description provided for @topHelperFixingCiRepos.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{fixing CI in 1 repo…} other{fixing CI in {n} repos…}}'**
  String topHelperFixingCiRepos(int n);

  /// No description provided for @topHelperCiDone.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{Done · CI fixed and pushed in {fixed} of 1 repo} other{Done · CI fixed and pushed in {fixed} of {total} repos}}'**
  String topHelperCiDone(int fixed, int total);

  /// No description provided for @topBusyFixingCi.
  ///
  /// In en, this message translates to:
  /// **'Fixing CI…'**
  String get topBusyFixingCi;

  /// No description provided for @topCiFixFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not fix CI'**
  String get topCiFixFailed;

  /// No description provided for @topHelperFetchingCiLog.
  ///
  /// In en, this message translates to:
  /// **'Get the error from the CI run'**
  String get topHelperFetchingCiLog;

  /// No description provided for @topAgentChangedNotPushed.
  ///
  /// In en, this message translates to:
  /// **'Changed but not pushed: {text}'**
  String topAgentChangedNotPushed(String text);

  /// No description provided for @topAgentNoChange.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed: {text}'**
  String topAgentNoChange(String text);

  /// No description provided for @topFixAwaitingPush.
  ///
  /// In en, this message translates to:
  /// **'Fix waiting to be pushed'**
  String get topFixAwaitingPush;

  /// No description provided for @topNoChangeSeeAgent.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed · see the agent\'s explanation'**
  String get topNoChangeSeeAgent;

  /// No description provided for @topFixedWatchingCi.
  ///
  /// In en, this message translates to:
  /// **'Fixed and pushed · watching the new CI run'**
  String get topFixedWatchingCi;

  /// No description provided for @topHelperProblem.
  ///
  /// In en, this message translates to:
  /// **'Problem: {error}. An AI agent is taking over'**
  String topHelperProblem(String error);

  /// No description provided for @topAgentNotFinished.
  ///
  /// In en, this message translates to:
  /// **'Not finished: {text}'**
  String topAgentNotFinished(String text);

  /// No description provided for @topAgentWorking.
  ///
  /// In en, this message translates to:
  /// **'{agent} is working…'**
  String topAgentWorking(String agent);

  /// No description provided for @topAgentFinished.
  ///
  /// In en, this message translates to:
  /// **'AI agent finished'**
  String get topAgentFinished;

  /// No description provided for @topAgentCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'The AI agent could not start: {error}'**
  String topAgentCouldNotStart(String error);

  /// No description provided for @mbOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open GIT Watcher'**
  String get mbOpenApp;

  /// No description provided for @mbRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get mbRefresh;

  /// No description provided for @mbQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit GIT Watcher'**
  String get mbQuit;

  /// No description provided for @mbAllClean.
  ///
  /// In en, this message translates to:
  /// **'Everything is in order'**
  String get mbAllClean;

  /// No description provided for @mbAllCleanBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing to commit, nothing to push, no CI running.'**
  String get mbAllCleanBody;

  /// No description provided for @mbAiShip.
  ///
  /// In en, this message translates to:
  /// **'AI commit & push'**
  String get mbAiShip;

  /// No description provided for @mbAiCommit.
  ///
  /// In en, this message translates to:
  /// **'AI commit'**
  String get mbAiCommit;

  /// No description provided for @mbAiCommitTooltip.
  ///
  /// In en, this message translates to:
  /// **'AI writes the message and commits this repository. The push is yours.'**
  String get mbAiCommitTooltip;

  /// No description provided for @mbShipAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'AI writes the message, commits and pushes every repository with work waiting'**
  String get mbShipAllTooltip;

  /// No description provided for @mbPush.
  ///
  /// In en, this message translates to:
  /// **'Push {n}'**
  String mbPush(int n);

  /// No description provided for @mbPushOnly.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get mbPushOnly;

  /// No description provided for @mbBehind.
  ///
  /// In en, this message translates to:
  /// **'{n} behind'**
  String mbBehind(int n);

  /// No description provided for @mbOpenRepo.
  ///
  /// In en, this message translates to:
  /// **'Open in the app'**
  String get mbOpenRepo;

  /// No description provided for @mbFiles.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 file} other{{n} files}}'**
  String mbFiles(int n);

  /// No description provided for @mbMoreFiles.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 more file} other{{n} more files}}'**
  String mbMoreFiles(int n);

  /// No description provided for @mbFooterHint.
  ///
  /// In en, this message translates to:
  /// **'Double-click the menu bar icon to open the window'**
  String get mbFooterHint;

  /// No description provided for @mbShipped.
  ///
  /// In en, this message translates to:
  /// **'{repo}: committed and pushed'**
  String mbShipped(String repo);

  /// No description provided for @mbCommitted.
  ///
  /// In en, this message translates to:
  /// **'{repo}: committed'**
  String mbCommitted(String repo);

  /// No description provided for @mbCommitFailed.
  ///
  /// In en, this message translates to:
  /// **'{repo}: could not be committed'**
  String mbCommitFailed(String repo);

  /// No description provided for @mbShipFailed.
  ///
  /// In en, this message translates to:
  /// **'{repo}: could not be shipped'**
  String mbShipFailed(String repo);

  /// No description provided for @mbPushed.
  ///
  /// In en, this message translates to:
  /// **'{repo}: pushed'**
  String mbPushed(String repo);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'is'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'is':
      return AppLocalizationsIs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
