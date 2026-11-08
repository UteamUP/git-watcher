import 'package:git_watcher_core/git_watcher_core.dart';

/// GIT Watcher MCP server: lets AI agents read and act on the watched repositories.
Future<void> main() async {
  final env = await ProcessEnv.resolve();
  await runMcpServer(GitWatcherService(Git(env)), CiService(env));
}
