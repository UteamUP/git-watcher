// Manual check: prints the CI state GIT Watcher would show for each repo given on the command line.
import 'package:git_watcher_core/git_watcher_core.dart';

Future<void> main(List<String> repos) async {
  final env = await ProcessEnv.resolve();
  final service = GitWatcherService(Git(env));
  final ci = CiService(env);
  for (final repo in repos) {
    final status = await service.status(repo);
    final result = await ci.status(repo, status.branch);
    print('${repoDisplayName(repo)}: ${result.state.name} job=${result.failedJob} failedRuns=${result.failedRuns}');
  }
}
