import 'dart:async';

import 'package:flutter/material.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import 'pages/overview_page.dart';
import 'state/watcher_controller.dart';
import 'theme.dart';
import 'ui/wallpaper.dart';
import 'widgets/repo_icon.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GitWatcherApp());
}

class GitWatcherApp extends StatefulWidget {
  const GitWatcherApp({super.key});

  @override
  State<GitWatcherApp> createState() => _GitWatcherAppState();
}

class _GitWatcherAppState extends State<GitWatcherApp> {
  late final Future<WatcherController> _controller = _start();

  static Future<WatcherController> _start() async {
    final env = await ProcessEnv.resolve();
    final controller = WatcherController(env: env, config: WatcherConfig.load());
    unawaited(controller.start());
    return controller;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GIT Watcher',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Text is set a little larger than macOS defaults so it reads easily on the glass.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.06)),
          child: Stack(fit: StackFit.expand, children: [
            const Wallpaper(),
            BackdropGroup(child: child!),
          ]),
        ),
        home: FutureBuilder<WatcherController>(
          future: _controller,
          builder: (context, snapshot) => snapshot.hasData
              ? OverviewPage(controller: snapshot.data!)
              : const Scaffold(
                  body: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      LogoTile(size: 72),
                      SizedBox(height: 18),
                      SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.blue)),
                    ]),
                  ),
                ),
        ),
      );
}
