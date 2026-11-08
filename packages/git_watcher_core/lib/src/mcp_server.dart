import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ci.dart';
import 'config.dart';
import 'models.dart';
import 'repo_service.dart';

const mcpServerVersion = '1.0.0';
const _protocolVersions = ['2025-11-25', '2025-06-18', '2025-03-26', '2024-11-05'];

class _Tool {
  const _Tool(this.name, this.description, this.properties, {this.required = const [], this.readOnly = false});

  final String name;
  final String description;
  final Map<String, Object?> properties;
  final List<String> required;
  final bool readOnly;

  Map<String, Object?> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': {'type': 'object', 'properties': properties, 'required': required},
        'annotations': {'readOnlyHint': readOnly, 'destructiveHint': false},
      };
}

const _repoArg = {'type': 'string', 'description': 'Repository folder name (UteamUP_Backend), short name (Backend) or absolute path'};

const _tools = [
  _Tool('list_repos', 'List every git repository GIT Watcher watches, with branch, changed files, ahead/behind and last commit.', {},
      readOnly: true),
  _Tool('repo_status', 'Changed files of one repository with per-file added/deleted line counts.', {'repo': _repoArg},
      required: ['repo'], readOnly: true),
  _Tool(
      'file_diff',
      'Unified diff of one file: the uncommitted change, or the change made by a commit when "commit" is given.',
      {
        'repo': _repoArg,
        'path': {'type': 'string', 'description': 'File path relative to the repository root'},
        'commit': {'type': 'string', 'description': 'Optional commit hash'},
      },
      required: ['repo', 'path'],
      readOnly: true),
  _Tool(
      'repo_log',
      'Recent commits, newest first, marking which are not pushed yet.',
      {
        'repo': _repoArg,
        'limit': {'type': 'integer', 'description': 'How many commits (default 20, max 200)'},
      },
      required: ['repo'],
      readOnly: true),
  _Tool(
      'commit_details',
      'Files changed by one commit.',
      {
        'repo': _repoArg,
        'commit': {'type': 'string'},
      },
      required: ['repo', 'commit'],
      readOnly: true),
  _Tool('ci_status', 'GitHub Actions state of the newest commit on the current branch, with progress while running.',
      {'repo': _repoArg},
      required: ['repo'], readOnly: true),
  _Tool(
      'commit',
      'Stage and commit changed files. Only the given paths are committed (all changed files when paths is omitted); other staged work is left alone. Use a Conventional Commit message.',
      {
        'repo': _repoArg,
        'message': {'type': 'string'},
        'paths': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Paths to commit; omit to commit every changed file',
        },
      },
      required: ['repo', 'message']),
  _Tool('push', 'Push the current branch, setting the upstream on first push. Never forces.', {'repo': _repoArg},
      required: ['repo']),
  _Tool('pull_rebase', 'git pull --rebase --autostash on the current branch.', {'repo': _repoArg}, required: ['repo']),
  _Tool('fetch', 'git fetch --all --prune for one repository, or for all when repo is omitted.', {'repo': _repoArg}),
];

/// Model Context Protocol server over stdio (newline-delimited JSON-RPC 2.0).
class McpServer {
  McpServer(this.service, this.ci);

  final GitWatcherService service;
  final CiService ci;

  Future<void> serve(Stream<List<int>> input, IOSink output) async {
    final pending = <Future<void>>[];
    await for (final line in input.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      pending.add(_respond(line, output));
    }
    await Future.wait(pending);
  }

  Future<void> _respond(String line, IOSink output) async {
    Map<String, Object?>? response;
    try {
      response = await handle(jsonDecode(line) as Map<String, Object?>);
    } on FormatException {
      response = _error(null, -32700, 'Parse error');
    }
    if (response != null) output.writeln(jsonEncode(response));
  }

  Future<Map<String, Object?>?> handle(Map<String, Object?> message) async {
    final id = message['id'];
    final isNotification = !message.containsKey('id');
    final params = (message['params'] as Map?)?.cast<String, Object?>() ?? const {};

    switch (message['method']) {
      case 'initialize':
        final requested = params['protocolVersion'];
        return _result(id, {
          'protocolVersion': _protocolVersions.contains(requested) ? requested : _protocolVersions[1],
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': {'name': 'git-watcher', 'title': 'GIT Watcher', 'version': mcpServerVersion},
          'instructions': 'GIT Watcher exposes the git repositories under ${WatcherConfig.load().root}. '
              'Call list_repos first. Repositories accept a folder name, a short name without the UteamUP_ prefix, '
              'or an absolute path. Use Conventional Commit messages, never force-push, and commit only your own changes.',
        });
      case 'ping':
        return _result(id, {});
      case 'tools/list':
        return _result(id, {'tools': [for (final tool in _tools) tool.toJson()]});
      case 'tools/call':
        return _result(id, await _call(params));
      default:
        return isNotification ? null : _error(id, -32601, 'Method not found: ${message['method']}');
    }
  }

  Future<Map<String, Object?>> _call(Map<String, Object?> params) async {
    final args = (params['arguments'] as Map?)?.cast<String, Object?>() ?? const {};
    try {
      final result = await _dispatch(params['name'] as String?, args);
      final text = result is String ? result : const JsonEncoder.withIndent('  ').convert(result);
      return {
        'content': [
          {'type': 'text', 'text': text},
        ],
        'isError': false,
      };
    } on Object catch (error) {
      return {
        'content': [
          {'type': 'text', 'text': 'Error: $error'},
        ],
        'isError': true,
      };
    }
  }

  Future<Object?> _dispatch(String? name, Map<String, Object?> args) async {
    switch (name) {
      case 'list_repos':
        final config = WatcherConfig.load();
        final repos = await GitWatcherService.discoverRepos(config.root, recursive: config.recursive);
        return Future.wait(repos.map((path) async {
          try {
            final status = await service.status(path);
            return {'name': repoFolderName(path), 'path': path, ...status.toJson(includeFiles: false)};
          } on Object catch (error) {
            return {'name': repoFolderName(path), 'path': path, 'error': '$error'};
          }
        }));
      case 'repo_status':
        final repo = await _resolve(args['repo']);
        final status = await service.status(repo);
        final stats = await service.lineStats(repo, status);
        return {
          'path': repo,
          ...status.toJson(includeFiles: false),
          'files': [
            for (final file in status.files)
              {...file.toJson(), 'added': stats[file.path]?.added, 'deleted': stats[file.path]?.deleted},
          ],
        };
      case 'file_diff':
        final repo = await _resolve(args['repo']);
        final path = _string(args, 'path');
        final commit = args['commit'] as String?;
        final String diff;
        if (commit != null && commit.isNotEmpty) {
          final files = await service.commitFiles(repo, commit);
          final file = files.firstWhere((f) => f.path == path, orElse: () => FileChange(path: path, kind: ChangeKind.modified));
          diff = await service.rawCommitDiff(repo, commit, file);
        } else {
          final status = await service.status(repo);
          final file = status.files.firstWhere((f) => f.path == path,
              orElse: () => throw ArgumentError('$path has no uncommitted change'));
          diff = await service.rawWorkingDiff(repo, file, hasCommits: status.hasCommits);
        }
        return diff.length > 200000 ? '${diff.substring(0, 200000)}\n[diff truncated]' : diff;
      case 'repo_log':
        final repo = await _resolve(args['repo']);
        final limit = ((args['limit'] as num?)?.toInt() ?? 20).clamp(1, 200);
        return [for (final commit in await service.log(repo, limit: limit)) commit.toJson()];
      case 'commit_details':
        final repo = await _resolve(args['repo']);
        return [for (final file in await service.commitFiles(repo, _string(args, 'commit'))) file.toJson()];
      case 'ci_status':
        final repo = await _resolve(args['repo']);
        final status = await service.status(repo);
        return (await ci.status(repo, status.branch)).toJson();
      case 'commit':
        final repo = await _resolve(args['repo']);
        final status = await service.status(repo);
        final wanted = (args['paths'] as List?)?.cast<String>();
        final files = wanted == null
            ? status.files
            : status.files.where((f) => wanted.contains(f.path) || wanted.contains(f.originalPath)).toList();
        if (wanted != null && files.length != wanted.length) {
          final known = {for (final f in files) ...f.pathspecs};
          throw ArgumentError('No uncommitted change for: ${wanted.where((p) => !known.contains(p)).join(', ')}');
        }
        final hash = await service.commit(repo, files, _string(args, 'message'), operation: status.operation);
        return {'commit': hash, 'files': files.length};
      case 'push':
        return service.push(await _resolve(args['repo']));
      case 'pull_rebase':
        return service.pullRebase(await _resolve(args['repo']));
      case 'fetch':
        if (args['repo'] == null) {
          final config = WatcherConfig.load();
          final repos = await GitWatcherService.discoverRepos(config.root, recursive: config.recursive);
          final results = await Future.wait(repos.map((path) async {
            try {
              await service.fetch(path);
              return '${repoFolderName(path)}: ok';
            } on Object catch (error) {
              return '${repoFolderName(path)}: $error';
            }
          }));
          return results.join('\n');
        }
        return service.fetch(await _resolve(args['repo']));
      default:
        throw ArgumentError('Unknown tool: $name');
    }
  }

  static String _string(Map<String, Object?> args, String key) {
    final value = args[key];
    if (value is! String || value.trim().isEmpty) throw ArgumentError('"$key" is required');
    return value;
  }

  /// Only repositories under the watched folder are reachable, so an agent cannot wander off.
  Future<String> _resolve(Object? value) async {
    if (value is! String || value.trim().isEmpty) throw ArgumentError('"repo" is required');
    final wanted = value.trim();
    final config = WatcherConfig.load();
    final repos = await GitWatcherService.discoverRepos(config.root, recursive: config.recursive);
    for (final repo in repos) {
      if (repo == wanted ||
          repoFolderName(repo).toLowerCase() == wanted.toLowerCase() ||
          repoDisplayName(repo).toLowerCase() == wanted.toLowerCase()) {
        return repo;
      }
    }
    throw ArgumentError('Unknown repo "$wanted". Known: ${repos.map(repoFolderName).join(', ')}');
  }

  static Map<String, Object?> _result(Object? id, Object? result) => {'jsonrpc': '2.0', 'id': id, 'result': result};

  static Map<String, Object?> _error(Object? id, int code, String message) => {
        'jsonrpc': '2.0',
        'id': id,
        'error': {'code': code, 'message': message},
      };
}

/// Entry point used by bin/git_watcher_mcp.dart.
Future<void> runMcpServer(GitWatcherService service, CiService ci) async {
  await McpServer(service, ci).serve(stdin, stdout);
  await stdout.flush();
}
