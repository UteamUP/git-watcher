import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:git_watcher/l10n/l10n.dart';
import 'package:git_watcher/state/watcher_controller.dart';
import 'package:git_watcher/widgets/ok_stack.dart';

void main() {
  Future<int Function()> pumpPile(WidgetTester tester, AnimationController open, Locale locale) async {
    final repos = [RepoState('/x/UteamUP_Alpha', null), RepoState('/x/UteamUP_Beta', null)];
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 300, height: 404, child: OkStack(repos: repos, open: open, onTap: () => taps++)),
        ),
      ),
    ));
    return () => taps;
  }

  testWidgets('the pile counts the repos that are fine and flips its label when opened', (tester) async {
    final open = AnimationController(vsync: const TestVSync(), duration: const Duration(milliseconds: 100));
    final taps = await pumpPile(tester, open, const Locale('en'));

    expect(find.text('Show all 2'), findsOneWidget);
    await tester.tap(find.byType(OkStack));
    expect(taps(), 1);

    open.value = 1;
    await tester.pump();
    expect(find.text('Stack again'), findsOneWidget);
    open.dispose();
  });

  testWidgets('the pile speaks Icelandic when Icelandic is chosen', (tester) async {
    final open = AnimationController(vsync: const TestVSync(), duration: const Duration(milliseconds: 100));
    await pumpPile(tester, open, const Locale('is'));

    expect(find.text('Sýna öll 2'), findsOneWidget);
    expect(find.text('Allt í lagi'), findsOneWidget);
    open.dispose();
  });
}
