import 'package:flutter_test/flutter_test.dart';
import 'package:git_watcher/format.dart';
import 'package:git_watcher/ui/layout.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

void main() {
  test('the grid never shows more than five columns and shrinks with the window', () {
    expect(columnsFor(4000), 5);
    expect(columnsFor(5 * minCardWidth + 4 * cardGap), 5);
    expect(columnsFor(5 * minCardWidth + 4 * cardGap - 1), 4);
    expect(columnsFor(2 * minCardWidth + cardGap), 2);
    expect(columnsFor(100), 1);
  });

  test('relative time reads naturally in Icelandic', () {
    final now = DateTime(2026, 11, 8, 12);
    expect(relativeTime(now.subtract(const Duration(seconds: 20)), now: now), 'rétt í þessu');
    expect(relativeTime(now.subtract(const Duration(minutes: 12)), now: now), 'fyrir 12 mín');
    expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now), 'fyrir 3 klst');
    expect(relativeTime(now.subtract(const Duration(days: 1)), now: now), 'í gær');
    expect(relativeTime(now.subtract(const Duration(days: 3)), now: now), 'fyrir 3 dögum');
    expect(relativeTime(DateTime(2025, 3, 2), now: now), '2. mar 2025');
    expect(relativeTime(null), 'ekkert commit');
  });

  test('CI labels show progress while running and the failing job when red', () {
    expect(ciLabel(const CiStatus(state: CiState.running, doneJobs: 7, totalJobs: 11)), '7 af 11 verkum');
    expect(ciLabel(const CiStatus(state: CiState.failure, failedJob: 'lint')), 'Mistókst í lint');
    expect(ciLabel(CiStatus.none), 'Ekkert CI pipeline');
  });

  test('large counts are shortened so they fit in a button', () {
    expect(compactCount(999), '999');
    expect(compactCount(2171), '2k');
  });
}
