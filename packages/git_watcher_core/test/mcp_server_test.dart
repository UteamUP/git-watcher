import 'package:git_watcher_core/git_watcher_core.dart';
import 'package:test/test.dart';

void main() {
  late McpServer server;

  setUpAll(() async {
    final env = await ProcessEnv.resolve();
    server = McpServer(GitWatcherService(Git(env)), CiService(env));
  });

  test('initialize echoes a supported protocol version and falls back otherwise', () async {
    final known = await server.handle({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {'protocolVersion': '2025-03-26'}});
    expect((known!['result'] as Map)['protocolVersion'], '2025-03-26');
    final unknown = await server.handle({'jsonrpc': '2.0', 'id': 2, 'method': 'initialize', 'params': {'protocolVersion': '1999-01-01'}});
    expect((unknown!['result'] as Map)['protocolVersion'], '2025-06-18');
    expect(((unknown['result'] as Map)['serverInfo'] as Map)['name'], 'git-watcher');
  });

  test('tools/list exposes read and write tools with schemas', () async {
    final response = await server.handle({'jsonrpc': '2.0', 'id': 3, 'method': 'tools/list'});
    final tools = ((response!['result'] as Map)['tools'] as List).cast<Map>();
    expect(tools.map((t) => t['name']), containsAll(['list_repos', 'repo_status', 'file_diff', 'repo_log', 'commit', 'push', 'ci_status']));
    final commit = tools.firstWhere((t) => t['name'] == 'commit');
    expect((commit['inputSchema'] as Map)['required'], ['repo', 'message']);
    expect((tools.firstWhere((t) => t['name'] == 'repo_log')['annotations'] as Map)['readOnlyHint'], isTrue);
  });

  test('notifications get no response and unknown methods get -32601', () async {
    expect(await server.handle({'jsonrpc': '2.0', 'method': 'notifications/initialized'}), isNull);
    final error = await server.handle({'jsonrpc': '2.0', 'id': 4, 'method': 'does/not/exist'});
    expect((error!['error'] as Map)['code'], -32601);
  });

  test('a tool call with bad arguments returns isError instead of crashing', () async {
    final missing = await server.handle({
      'jsonrpc': '2.0',
      'id': 5,
      'method': 'tools/call',
      'params': {'name': 'repo_status', 'arguments': <String, Object?>{}},
    });
    expect((missing!['result'] as Map)['isError'], isTrue);

    final outside = await server.handle({
      'jsonrpc': '2.0',
      'id': 6,
      'method': 'tools/call',
      'params': {
        'name': 'repo_status',
        'arguments': {'repo': '/etc'},
      },
    });
    final result = outside!['result'] as Map;
    expect(result['isError'], isTrue);
    expect(((result['content'] as List).single as Map)['text'], contains('Unknown repo'));
  });
}
