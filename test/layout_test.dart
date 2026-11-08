import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:git_watcher/format.dart';
import 'package:git_watcher/l10n/l10n.dart';
import 'package:git_watcher/ui/layout.dart';
import 'package:git_watcher_core/git_watcher_core.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final icelandic = lookupAppLocalizations(const Locale('is'));
  setUpAll(initializeDateFormatting);

  test('the grid never shows more than five columns and shrinks with the window', () {
    expect(columnsFor(4000), 5);
    expect(columnsFor(5 * minCardWidth + 4 * cardGap), 5);
    expect(columnsFor(5 * minCardWidth + 4 * cardGap - 1), 4);
    expect(columnsFor(2 * minCardWidth + cardGap), 2);
    expect(columnsFor(100), 1);
  });

  test('a saved language the app does not have falls back to English', () {
    expect(supportedLocale('is'), const Locale('is'));
    expect(supportedLocale('de'), const Locale('en'));
  });

  test('relative time reads naturally in English and Icelandic', () {
    final now = DateTime(2026, 11, 8, 12);
    expect(relativeTime(en, now.subtract(const Duration(seconds: 20)), now: now), 'just now');
    expect(relativeTime(en, now.subtract(const Duration(minutes: 12)), now: now), '12 min ago');
    expect(relativeTime(en, now.subtract(const Duration(days: 1)), now: now), 'yesterday');
    expect(relativeTime(en, DateTime(2025, 3, 2), now: now), 'Mar 2, 2025');
    expect(relativeTime(en, null), 'no commits');

    expect(relativeTime(icelandic, now.subtract(const Duration(seconds: 20)), now: now), 'rétt í þessu');
    expect(relativeTime(icelandic, now.subtract(const Duration(minutes: 12)), now: now), 'fyrir 12 mín');
    expect(relativeTime(icelandic, now.subtract(const Duration(hours: 3)), now: now), 'fyrir 3 klst');
    expect(relativeTime(icelandic, now.subtract(const Duration(days: 3)), now: now), 'fyrir 3 dögum');
    expect(relativeTime(icelandic, null), 'ekkert commit');
  });

  test('CI labels show progress while running and the failing job when red', () {
    expect(ciLabel(en, const CiStatus(state: CiState.running, doneJobs: 7, totalJobs: 11)), '7 of 11 jobs');
    expect(ciLabel(icelandic, const CiStatus(state: CiState.running, doneJobs: 7, totalJobs: 11)), '7 af 11 verkum');
    expect(ciLabel(en, const CiStatus(state: CiState.failure, failedJob: 'lint')), 'Failed in lint');
    expect(ciLabel(icelandic, const CiStatus(state: CiState.failure, failedJob: 'lint')), 'Mistókst í lint');
    expect(ciLabel(en, CiStatus.none), 'No CI pipeline');
  });

  test('counts follow each language\'s plural rules', () {
    expect(en.fileCount(1), '1 file');
    expect(en.fileCount(21), '21 files');
    expect(icelandic.fileCount(1), '1 skrá');
    expect(icelandic.fileCount(21), '21 skrá');
    expect(icelandic.fileCount(11), '11 skrár');
    expect(en.commitsAhead(2), '2 commits to push');
    expect(icelandic.commitsAhead(1), '1 commit bíður push');
  });

  test('AI errors are shown in the chosen language, git errors as git said them', () {
    const error = AiException(AiText.timedOut, 'codex did not answer within 3 minutes', detail: 'codex');
    expect(errorText(en, error), 'codex did not answer within 3 minutes');
    expect(errorText(icelandic, error), 'codex svaraði ekki innan 3 mínútna');
    expect(errorText(icelandic, const GitException('fatal: not a git repository')), 'fatal: not a git repository');
    expect(agentEventText(icelandic, const AgentEvent('x', kind: AiText.agentOff)), 'AI agent er óvirkur í Stillingum');
  });

  test('large counts are shortened so they fit in a button', () {
    expect(compactCount(999), '999');
    expect(compactCount(2171), '2k');
  });
}
