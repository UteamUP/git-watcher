import 'package:git_watcher_core/git_watcher_core.dart';

/// Manual check of the AI providers that need no API key: dart run tool/ai_smoke.dart
Future<void> main() async {
  final ai = AiService(await ProcessEnv.resolve());
  print('claude signed in: ${await ai.claudeLoggedIn()}, codex signed in: ${await ai.codexLoggedIn()}');
  for (final provider in [AiProvider.codex, AiProvider.claudeCode, AiProvider.anthropic]) {
    try {
      final message = await ai.commitMessage(
        settings: AiSettings(provider: provider, model: provider.defaultModel, baseUrl: provider.defaultBaseUrl),
        repoName: 'demo',
        changes: 'diff --git a/README.md b/README.md\n+Add install steps for macOS\n',
        recentSubjects: const ['docs: explain setup'],
        subjectOnly: true,
      );
      print('${provider.name}: OK -> $message');
    } on Object catch (error) {
      print('${provider.name}: ERROR -> $error');
    }
  }
}
