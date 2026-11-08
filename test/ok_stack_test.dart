import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:git_watcher/state/watcher_controller.dart';
import 'package:git_watcher/widgets/ok_stack.dart';

void main() {
  testWidgets('the pile counts the repos that are fine and flips its label when opened', (tester) async {
    final open = AnimationController(vsync: const TestVSync(), duration: const Duration(milliseconds: 100));
    final repos = [RepoState('/x/UteamUP_Alpha', null), RepoState('/x/UteamUP_Beta', null)];
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 300, height: 404, child: OkStack(repos: repos, open: open, onTap: () => taps++)),
        ),
      ),
    ));

    expect(find.text('Sýna öll 2'), findsOneWidget);
    expect(find.text('2 repo · ekkert að commita eða pusha'), findsOneWidget);
    await tester.tap(find.byType(OkStack));
    expect(taps, 1);

    open.value = 1;
    await tester.pump();
    expect(find.text('Stafla aftur'), findsOneWidget);
    open.dispose();
  });
}
