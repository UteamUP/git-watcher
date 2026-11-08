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
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (_) => _window.invokeMethod<void>('startDrag'),
        child: child,
      );
}

Future<void> openInFinder(String path) => Process.run('open', [path]);

Future<void> revealInFinder(String path) => Process.run('open', ['-R', path]);

Future<void> openInTerminal(String path) => Process.run('open', ['-a', 'Terminal', path]);

Future<void> openInVsCode(String path) => Process.run('open', ['-b', 'com.microsoft.VSCode', path]);

Future<void> openUrl(String url) => Process.run('open', [url]);

/// Opens Terminal and runs [command], for sign-in flows that need the user at the keyboard.
Future<void> openTerminalCommand(String command) => Process.run('osascript', [
      '-e', 'tell application "Terminal" to activate',
      '-e', 'tell application "Terminal" to do script "$command"',
    ]);

/// A macOS notification, shown by the system even when the window is in the background.
Future<void> notifyMac(String title, String body) {
  String quote(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  return Process.run('osascript', ['-e', 'display notification ${quote(body)} with title ${quote(title)}']);
}
