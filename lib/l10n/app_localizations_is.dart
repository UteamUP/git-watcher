// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Icelandic (`is`).
class AppLocalizationsIs extends AppLocalizations {
  AppLocalizationsIs([String locale = 'is']) : super(locale);

  @override
  String get languageEnglish => 'English';

  @override
  String get languageIcelandic => 'Íslenska';

  @override
  String get noCommits => 'ekkert commit';

  @override
  String get justNow => 'rétt í þessu';

  @override
  String minutesAgo(int n) {
    return 'fyrir $n mín';
  }

  @override
  String hoursAgo(int n) {
    return 'fyrir $n klst';
  }

  @override
  String get yesterday => 'í gær';

  @override
  String daysAgo(int n) {
    return 'fyrir $n dögum';
  }

  @override
  String get aWeekAgo => 'fyrir viku';

  @override
  String weeksAgo(int n) {
    return 'fyrir $n vikum';
  }

  @override
  String get durationUnderMinute => '< 1 mín';

  @override
  String durationMinutes(int minutes) {
    return '$minutes mín';
  }

  @override
  String durationHours(int hours, int minutes) {
    return '$hours klst $minutes mín';
  }

  @override
  String get kindModified => 'breytt';

  @override
  String get kindAdded => 'ný';

  @override
  String get kindDeleted => 'eytt';

  @override
  String get kindRenamed => 'færð';

  @override
  String get kindUntracked => 'óskráð';

  @override
  String get kindConflicted => 'árekstur';

  @override
  String get ciNone => 'Ekkert CI pipeline';

  @override
  String get ciQueued => 'Í biðröð';

  @override
  String ciJobs(int done, int total) {
    return '$done af $total verkum';
  }

  @override
  String ciPassed(String duration) {
    return 'Tókst · $duration';
  }

  @override
  String get ciFailed => 'Mistókst';

  @override
  String ciFailedIn(String job) {
    return 'Mistókst í $job';
  }

  @override
  String get ciCancelled => 'Hætt við';

  @override
  String get almostDone => 'næstum búið';

  @override
  String minutesLeft(int n) {
    return '≈ $n mín eftir';
  }

  @override
  String commitsAhead(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n commit bíða push',
      one: '$n commit bíður push',
    );
    return '$_temp0';
  }

  @override
  String commitsBehind(int n) {
    return '$n commit á eftir remote';
  }

  @override
  String fileCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n skrár',
      one: '$n skrá',
    );
    return '$_temp0';
  }

  @override
  String get speedCodex => 'getur tekið allt að mínútu';

  @override
  String get speedClaudeCode => 'tekur nokkrar sekúndur';

  @override
  String get speedApi => 'tekur 1–5 sekúndur';

  @override
  String get providerCustom => 'OpenAI-samhæft API';

  @override
  String get agentOff => 'Slökkt';

  @override
  String get aiBadKey =>
      'Lykillinn má ekki vera tómur eða innihalda bil, gæsalappir eða bakstrik';

  @override
  String aiKeychainFailed(String detail) {
    return 'Gat ekki vistað lykilinn í Keychain: $detail';
  }

  @override
  String get aiEmptyReply => 'AI skilaði tómu svari';

  @override
  String aiCliMissing(String tool) {
    return '$tool fannst ekki á þessari vél';
  }

  @override
  String get aiClaudeSignedOut =>
      'Claude Code er ekki innskráð. Opnaðu Stillingar og smelltu á Skrá inn, eða veldu annað AI.';

  @override
  String aiTimedOut(String tool) {
    return '$tool svaraði ekki innan 3 mínútna';
  }

  @override
  String aiCliFailed(String detail) {
    return 'AI gat ekki skrifað skilaboð: $detail';
  }

  @override
  String get aiRefused => 'Claude neitaði að skrifa þessi skilaboð';

  @override
  String get aiNoModel => 'Veldu módel í Stillingum';

  @override
  String get aiNoKey =>
      'Enginn API lykill vistaður. Settu hann inn í Stillingum.';

  @override
  String aiHttpStatus(String detail) {
    return 'AI þjónustan svaraði $detail';
  }

  @override
  String aiUnreachable(String host) {
    return 'Næ ekki sambandi við $host';
  }

  @override
  String get aiAgentOff => 'AI agent er óvirkur í Stillingum';

  @override
  String aiAgentStopped(String detail) {
    return '$detail stöðvaðist';
  }

  @override
  String aiAgentFinished(String detail) {
    return '$detail kláraði';
  }

  @override
  String get cardViewChanges => 'Skoða breytingar og sögu';

  @override
  String get cardCommitHint => 'Skrifaðu commit skilaboð';

  @override
  String get nothingToCommit => 'Ekkert að commita';

  @override
  String cardAiWriting(String provider, String speed) {
    return '$provider skrifar skilaboð · $speed';
  }

  @override
  String get cardAiWriteTooltip => 'Láta AI skrifa skilaboð';

  @override
  String get cardReadingStatus => 'Les stöðu…';

  @override
  String get cardCleanTree => 'Hreint vinnusvæði';

  @override
  String cardOperationInProgress(String operation) {
    return '$operation í gangi';
  }

  @override
  String get cardNoUpstream => 'Ekkert upstream';

  @override
  String cardUpToDate(String upstream) {
    return 'Í takt við $upstream';
  }

  @override
  String get cardNoCommits => 'Ekkert commit';

  @override
  String get cardFixCi => 'Laga';

  @override
  String get cardFixCiTooltip => 'Láta AI laga CI villuna, commita og pusha';

  @override
  String get cardCiWatching => 'Fylgst með CI: tilkynning þegar keyrslu lýkur';

  @override
  String get cardWatchCi => 'Fylgjast með CI';

  @override
  String get cardMenuUseAgent => 'Nota AI agent';

  @override
  String get cardMenuUseAgentHint => 'Skrifar, commitar og pushar';

  @override
  String get pullWithRebase => 'Pull með rebase';

  @override
  String get cardMenuRebaseOnMain => 'Rebase á origin/main';

  @override
  String get cardMenuSync => 'Sync (pull og push)';

  @override
  String get cardMenuStash => 'Stash breytingar';

  @override
  String get cardMenuStashPop => 'Sækja stash';

  @override
  String cardMenuContinue(String operation) {
    return 'Halda áfram með $operation';
  }

  @override
  String cardMenuAbort(String operation) {
    return 'Hætta við $operation';
  }

  @override
  String get cardMenuFixCi => 'Laga CI með AI';

  @override
  String get cardMenuOpenCiRun => 'Opna CI keyrslu';

  @override
  String get openInVsCode => 'Opna í VS Code';

  @override
  String get cardMenuOpenFinder => 'Opna í Finder';

  @override
  String get cardMenuOpenTerminal => 'Opna í Terminal';

  @override
  String get cardMenuChangeIcon => 'Breyta icon…';

  @override
  String get cardMenuDefaultIcon => 'Nota sjálfgefið icon';

  @override
  String get cardMenuHideRepo => 'Fela repo';

  @override
  String get cardMenuMore => 'Fleiri aðgerðir';

  @override
  String get cardMenuImages => 'Myndir';

  @override
  String get cardChoose => 'Velja';

  @override
  String get cardFolderWatching => 'Fylgst með';

  @override
  String cardRepoCount(int n) {
    return '$n repo';
  }

  @override
  String get cardFolderRecent => 'Nýlegar möppur';

  @override
  String get cardFolderHidden => 'Falin repo · smelltu til að birta aftur';

  @override
  String get cardFolderRecursive => 'Leita í öllum undirmöppum';

  @override
  String get cardFolderChoose => 'Velja möppu…';

  @override
  String get repoBack => 'Til baka (⌘[)';

  @override
  String repoOperationInProgress(String operation) {
    return '$operation í gangi';
  }

  @override
  String get repoContinue => 'Halda áfram';

  @override
  String get repoAbort => 'Hætta við';

  @override
  String get fetchDone => 'Fetch lokið';

  @override
  String repoTabChanges(int count) {
    return 'Breytingar  $count';
  }

  @override
  String get repoTabHistory => 'Saga';

  @override
  String get repoClean => 'Vinnusvæðið er hreint.';

  @override
  String repoCleanWithAhead(String ahead) {
    return 'Vinnusvæðið er hreint, $ahead.';
  }

  @override
  String get repoViewHistory => 'Skoða sögu';

  @override
  String repoSelectedCount(int selected, int total) {
    return '$selected af $total valdar';
  }

  @override
  String get repoDiscardChanges => 'Afturkalla breytingar';

  @override
  String get repoShowInFinder => 'Sýna í Finder';

  @override
  String get repoDiscardChangesTitle => 'Afturkalla breytingar?';

  @override
  String get repoDiscard => 'Afturkalla';

  @override
  String repoDiscardNewFileBody(String path) {
    return '$path er ný skrá. Hún fer í ruslafötuna og þú getur sótt hana þangað.';
  }

  @override
  String repoDiscardChangesBody(String path) {
    return 'Breytingarnar á $path hverfa og ekki er hægt að fá þær aftur.';
  }

  @override
  String repoChangesDiscarded(String name) {
    return 'Breytingar á $name afturkallaðar';
  }

  @override
  String get repoCommitMessageHint => 'Commit skilaboð';

  @override
  String get repoWriteWithAi => 'Skrifa með AI';

  @override
  String get repoCommitAndPush => 'Commit og push';

  @override
  String repoCommittedAndPushed(String summary) {
    return '$summary og pushað';
  }

  @override
  String get repoNoCommitsYet => 'Engin commit enn';

  @override
  String get repoNotPushed => 'bíður push';

  @override
  String get repoSelectFile => 'Veldu skrá';

  @override
  String get repoSelectFileHint =>
      'Smelltu á skrá til að sjá hvað breyttist í henni.';

  @override
  String get repoNoticeBinary =>
      'Tvíundarskrá: ekki hægt að sýna breytingarnar';

  @override
  String get repoNoticeMissing => 'Skráin er ekki lengur til';

  @override
  String get repoNoticeDirectory => 'Þetta er mappa, oft annað git repo';

  @override
  String get repoNoticeTooLarge => 'Skráin er of stór til að sýna';

  @override
  String get repoNoticeEmpty =>
      'Engar breytingar á innihaldi, til dæmis bara á heimildum';

  @override
  String repoDiffTruncated(int n) {
    return 'Breytingin er of löng, aðeins fyrstu $n línurnar eru sýndar.';
  }

  @override
  String repoDonutFiles(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'skrár',
      one: 'skrá',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'Stillingar';

  @override
  String get close => 'Loka';

  @override
  String get settingsLanguage => 'Tungumál';

  @override
  String get settingsLanguageSubtitle => 'Gildir strax um allt forritið.';

  @override
  String get settingsCommitAiTitle => 'AI fyrir commit skilaboð';

  @override
  String get settingsCommitAiSubtitle =>
      'Notað af AI takkanum á kortunum, AI skilaboðum og AI helper.';

  @override
  String get settingsTest => 'Prófa';

  @override
  String settingsWaiting(int seconds, String speed) {
    return 'Bíð eftir svari · $seconds s · $speed';
  }

  @override
  String settingsTestWorks(String message) {
    return 'Virkar: $message';
  }

  @override
  String get settingsAgentTitle => 'AI agent sem lagar vandamál';

  @override
  String get settingsAgentSubtitle =>
      'Keyrir git sjálfur í repoinu þegar commit, rebase eða push stoppar: lagar árekstra og klárar verkið. Notar áskrift Claude Code eða Codex, því API lykill einn og sér getur ekki keyrt git.';

  @override
  String get settingsHiddenTitle => 'Falin repo';

  @override
  String get settingsHiddenSubtitle =>
      'Falin repo sjást ekki og eru ekki með í Commit allt, Push allt eða AI helper.';

  @override
  String get settingsNoHidden =>
      'Engin falin repo. Feldu repo í Fleiri aðgerðir á kortinu.';

  @override
  String get settingsShowAgain => 'Birta aftur';

  @override
  String settingsUsesSubscription(String speed) {
    return 'Notar áskriftina þína, $speed.';
  }

  @override
  String settingsSignedIn(String name) {
    return '$name: innskráð';
  }

  @override
  String settingsSignedOut(String name) {
    return '$name: ekki innskráð';
  }

  @override
  String get settingsSignIn => 'Skrá inn';

  @override
  String settingsSignInTooltip(String command) {
    return 'Opnar Terminal með $command';
  }

  @override
  String get settingsCheckAgain => 'Athuga aftur';

  @override
  String get settingsModel => 'Módel';

  @override
  String settingsModelExample(String model) {
    return 't.d. $model';
  }

  @override
  String get settingsBaseUrl => 'Slóð';

  @override
  String get settingsApiKey => 'API lykill';

  @override
  String get settingsKeySavedHint =>
      'Vistaður í Keychain · skrifaðu nýjan til að skipta';

  @override
  String get settingsKeyPasteHint => 'Límdu lykilinn hér';

  @override
  String get settingsSave => 'Vista';

  @override
  String get settingsKeySaved => 'Lykill vistaður í macOS Keychain';

  @override
  String get settingsDelete => 'Eyða';

  @override
  String appCiNotification(String repo, String status) {
    return '$repo: CI $status';
  }

  @override
  String get appWriteMessageFirst =>
      'Skrifaðu commit skilaboð fyrst, eða láttu AI skrifa þau.';

  @override
  String appCommitted(String hash, String repo) {
    return 'Commit $hash í $repo';
  }

  @override
  String get appBusyContinue => 'Held áfram…';

  @override
  String get appBusyAbort => 'Hætti við…';

  @override
  String get appBusyDiscard => 'Afturkalla…';

  @override
  String appSkippedNoMessage(String repo) {
    return '$repo: sleppt, engin skilaboð';
  }

  @override
  String appCommittedRepo(String repo) {
    return '$repo: commitað';
  }

  @override
  String appPushedRepo(String repo) {
    return '$repo: pushað';
  }

  @override
  String get topSettingsTooltip => 'Stillingar: AI og falin repo';

  @override
  String get topRefreshTooltip => 'Endurhlaða (⌘R)';

  @override
  String topFixAllCi(int n) {
    return 'Laga allt CI · $n';
  }

  @override
  String get topFixAllCiTooltip =>
      'AI agent lagar öll biluð CI, eitt repo í einu';

  @override
  String get topAiHelperTooltip =>
      'Skrifa skilaboð, commita og pusha öll repo, og laga vandamál';

  @override
  String get topAiMessages => 'AI skilaboð';

  @override
  String get topAiMessagesTooltip =>
      'Láta AI skrifa commit skilaboð í öll repo með breytingar';

  @override
  String get topCommitAll => 'Commit allt';

  @override
  String get topPushAll => 'Push allt';

  @override
  String get topFetchAll => 'Fetch allt';

  @override
  String topWithChanges(int n) {
    return '$n með breytingar';
  }

  @override
  String topWaitingPush(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n bíða push',
      one: '$n bíður push',
    );
    return '$_temp0';
  }

  @override
  String topCiRunning(int n) {
    return '$n CI í gangi';
  }

  @override
  String topCiFailed(int n) {
    return '$n CI mistókst';
  }

  @override
  String topPushRepos(int n) {
    return 'Pusha $n repo';
  }

  @override
  String get topScanning => 'Leita að git repo…';

  @override
  String get topNoRepos => 'Engin git repo fundust';

  @override
  String get topAllGood => 'Allt í lagi';

  @override
  String topNothingToShip(int n) {
    return '$n repo · ekkert að commita eða pusha';
  }

  @override
  String topShowAll(int n) {
    return 'Sýna öll $n';
  }

  @override
  String get topStackAgain => 'Stafla aftur';

  @override
  String get topErrorTitle => 'Þetta tókst ekki';

  @override
  String get topCancel => 'Hætta við';

  @override
  String get topNothingToCommitOrPush => 'Ekkert til að commita eða pusha';

  @override
  String topProviderSignedOut(String provider) {
    return '$provider er ekki innskráð. Opnaðu Stillingar og skráðu þig inn eða veldu API lykil.';
  }

  @override
  String topAiAgentFor(String repo) {
    return 'AI agent fyrir $repo';
  }

  @override
  String get topStart => 'Byrja';

  @override
  String topAiHelperIntro(String agent) {
    return 'AI skrifar commit skilaboð, commitar allar breytingar, sækir og rebase-ar ef þarf og pushar. Ef eitthvað stendur á tekur $agent við og lagar það.';
  }

  @override
  String get topNoAgentReady =>
      'Enginn AI agent er tilbúinn. Opnaðu Stillingar, veldu Claude Code eða Codex og skráðu þig inn.';

  @override
  String topFixCiIn(String repo) {
    return 'Laga CI í $repo';
  }

  @override
  String topFixAllCiRepos(int n) {
    return 'Laga allt CI · $n repo';
  }

  @override
  String get topFixCi => 'Laga CI';

  @override
  String topFixRepos(int n) {
    return 'Laga $n repo';
  }

  @override
  String topFixCiIntro(String agent) {
    return '$agent les villuna úr hverri CI keyrslu, lagar kóðann, commitar og pushar, eitt repo í einu. Hann notar hvorki --force né --no-verify og slekkur ekki á prófunum. Ef villan er ekki í kóðanum (t.d. vantar secret) breytir hann engu og útskýrir ástæðuna.';
  }

  @override
  String topHelperWorkingOn(int n) {
    return 'vinnur í $n repo…';
  }

  @override
  String topHelperDone(int done, int total) {
    return 'Búið · $done af $total repo kláruð';
  }

  @override
  String get topHelperWritingMessage => 'Skrifa commit skilaboð';

  @override
  String topHelperCommitFiles(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Commit $n skrár',
      one: 'Commit $n skrá',
    );
    return '$_temp0';
  }

  @override
  String topHelperPushTo(String remote) {
    return 'Push á $remote';
  }

  @override
  String topHelperFixingCiIn(String repo) {
    return 'lagar CI í $repo…';
  }

  @override
  String topHelperFixingCiRepos(int n) {
    return 'lagar CI í $n repo…';
  }

  @override
  String topHelperCiDone(int fixed, int total) {
    return 'Búið · CI lagað og pushað í $fixed af $total repo';
  }

  @override
  String get topBusyFixingCi => 'Lagar CI…';

  @override
  String get topCiFixFailed => 'Tókst ekki að laga CI';

  @override
  String get topHelperFetchingCiLog => 'Sæki villuna úr CI keyrslunni';

  @override
  String topAgentChangedNotPushed(String text) {
    return 'Breytt en ekki pushað: $text';
  }

  @override
  String topAgentNoChange(String text) {
    return 'Engu breytt: $text';
  }

  @override
  String get topFixAwaitingPush => 'Lagfæring bíður push';

  @override
  String get topNoChangeSeeAgent => 'Engu breytt · sjá skýringu agentsins';

  @override
  String get topFixedWatchingCi =>
      'Lagað og pushað · fylgist með nýrri CI keyrslu';

  @override
  String topHelperProblem(String error) {
    return 'Vandamál: $error. AI agent tekur við';
  }

  @override
  String topAgentNotFinished(String text) {
    return 'Ekki lokið: $text';
  }

  @override
  String topAgentWorking(String agent) {
    return '$agent vinnur…';
  }

  @override
  String get topAgentFinished => 'AI agent kláraði';

  @override
  String topAgentCouldNotStart(String error) {
    return 'AI agent gat ekki byrjað: $error';
  }
}
