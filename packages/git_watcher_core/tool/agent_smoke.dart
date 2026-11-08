import 'dart:io';

import 'package:git_watcher_core/git_watcher_core.dart';

/// Manual check of the Codex agent path in a throwaway repo: dart run tool/agent_smoke.dart
Future<void> main() async {
  final dir = await Directory.systemTemp.createTemp('gw_agent_');
  Future<void> git(List<String> a) => Process.run('git', a, workingDirectory: dir.path);
  await git(['init', '-q', '-b', 'main']);
  await git(['config', 'user.email', 'test@example.com']);
  await git(['config', 'user.name', 'Test']);
  await File('${dir.path}/notes.txt').writeAsString('first\n');
  final ai = AiService(await ProcessEnv.resolve());
  final started = DateTime.now();
  await for (final event in ai.runAgent(
    agent: AgentProvider.codex,
    repo: dir.path,
    task: 'Commit the untracked file notes.txt with the message "chore: add notes". Do not push. Reply with one short sentence.',
  )) {
    print('${DateTime.now().difference(started).inSeconds}s ${event.done ? (event.failed ? 'FAILED' : 'DONE') : 'step'}: ${event.text}');
  }
  print((await Process.run('git', ['log', '--oneline'], workingDirectory: dir.path)).stdout);
  await dir.delete(recursive: true);
}
