import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _window = MethodChannel('gitwatcher/window');

/// Lets the window be dragged by an area of the Flutter view (the title bar is transparent).
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: (_) => _window.invokeMethod<void>('startDrag'),
      child: child,
    );
  }
}

Future<void> openInFinder(String path) => Platform.isWindows
    ? Process.run('explorer', [path])
    : Process.run('open', [path]);

Future<void> revealInFinder(String path) => Platform.isWindows
    ? Process.run('explorer', ['/select,$path'])
    : Process.run('open', ['-R', path]);

Future<void> openInTerminal(String path) {
  if (Platform.isWindows) {
    final escaped = path.replaceAll("'", "''");
    return Process.run('cmd', ['/c', 'start', 'powershell', '-NoExit', '-Command', "Set-Location -LiteralPath '$escaped'"]);
  }
  return Process.run('open', ['-a', 'Terminal', path]);
}

Future<void> openInVsCode(String path) => Platform.isWindows
    ? Process.run('code', [path], runInShell: true)
    : Process.run('open', ['-b', 'com.microsoft.VSCode', path]);

Future<void> openUrl(String url) => Platform.isWindows
    ? Process.run('cmd', ['/c', 'start', '', url])
    : Process.run('open', [url]);

/// Opens Terminal and runs [command], for sign-in flows that need the user at the keyboard.
Future<void> openTerminalCommand(String command) {
  if (Platform.isWindows) {
    return Process.run('cmd', ['/c', 'start', 'powershell', '-NoExit', '-Command', command]);
  }
  return Process.run('osascript', [
    '-e', 'tell application "Terminal" to activate',
    '-e', 'tell application "Terminal" to do script "$command"',
  ]);
}

/// A macOS notification, shown by the system even when the window is in the background.
Future<void> notifyMac(String title, String body) {
  if (!Platform.isMacOS) return Future.value();
  String quote(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  return Process.run('osascript', ['-e', 'display notification ${quote(body)} with title ${quote(title)}']);
}
