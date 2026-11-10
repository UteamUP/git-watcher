import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import 'format.dart';
import 'l10n/l10n.dart';
import 'menu_bar/panel_app.dart';
import 'menu_bar/snapshot_builder.dart';
import 'pages/overview_page.dart';
import 'pages/repo_page.dart';
import 'state/watcher_controller.dart';
import 'theme.dart';
import 'ui/menu_bar.dart';
import 'ui/wallpaper.dart';
import 'widgets/repo_icon.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GitWatcherApp());
}

/// The entry point of the panel in the menu bar.
///
/// It runs in its own Flutter engine, so it holds no state: the main app pushes a snapshot into
/// it and the panel sends actions back.
@pragma('vm:entry-point')
void menuBarPanel() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MenuBarPanelApp());
}

class GitWatcherApp extends StatefulWidget {
  const GitWatcherApp({super.key});

  @override
  State<GitWatcherApp> createState() => _GitWatcherAppState();
}

class _GitWatcherAppState extends State<GitWatcherApp> {
  final _config = WatcherConfig.load();
  late final _locale = ValueNotifier(supportedLocale(_config.language));
  late final Future<WatcherController> _controller = _start();
  final _navigatorKey = GlobalKey<NavigatorState>();

  WatcherController? _watcher;
  Timer? _pushTimer;
  Timer? _noticeTimer;
  String? _notice;
  bool _noticeError = false;

  Future<WatcherController> _start() async {
    final env = await ProcessEnv.resolve();
    final controller = WatcherController(env: env, config: _config, locale: _locale);
    _watcher = controller;
    unawaited(controller.start());
    _watchMenuBar(controller);
    return controller;
  }

  /// The menu bar follows the app: every change is pushed to the panel and to the badge on the icon.
  void _watchMenuBar(WatcherController controller) {
    MenuBarBridge.handler = (call) => _handleMenuBarCall(controller, call);
    MenuBarBridge.listen();
    controller.addListener(() => _schedulePush(controller));
    _schedulePush(controller);
  }

  void _schedulePush(WatcherController controller) {
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(milliseconds: 200), () => _push(controller));
  }

  Future<void> _push(WatcherController controller) async {
    final snapshot = buildMenuBarSnapshot(controller, notice: _notice, noticeError: _noticeError);
    await MenuBarBridge.updateSummary(
      dirty: snapshot.dirty,
      ahead: snapshot.ahead,
      ciRunning: snapshot.ciRunning,
      ciFailed: snapshot.ciFailed,
    );
    await MenuBarBridge.sendSnapshot(snapshot.toJson());
  }

  /// A short line in the panel about what just happened.
  void _setNotice(String text, {bool error = false}) {
    _notice = text;
    _noticeError = error;
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 6), () {
      _notice = null;
      _noticeError = false;
      final controller = _watcher;
      if (controller != null) _schedulePush(controller);
    });
  }

  Future<void> _handleMenuBarCall(WatcherController controller, MethodCall call) async {
    switch (call.method) {
      case 'action':
        await _handleAction(controller, call.arguments);
      case 'showWindow':
        await MenuBarBridge.showWindow();
    }
  }

  /// The panel has no git of its own, so every action is done here.
  Future<void> _handleAction(WatcherController controller, Object? arguments) async {
    final args = arguments is Map ? arguments.cast<String, dynamic>() : const <String, dynamic>{};
    final method = args['method'] as String?;
    final path = args['path'] as String?;
    debugPrint('[GITWatcher] action $method');
    final repo = path == null ? null : controller.byPath(path);
    switch (method) {
      case 'aiShipAll':
        // One button for everything waiting: message, commit and push, one repository after another.
        final targets = controller.repos.where((repo) => repo.shippable).toList();
        if (targets.isEmpty) return;
        await controller.helper.run(targets);
      case 'aiShip':
        if (repo == null) return;
        final ok = await controller.helper.ship(repo);
        _setNotice(ok ? controller.l10n.mbShipped(repo.name) : controller.l10n.mbShipFailed(repo.name), error: !ok);
      case 'push':
        if (repo == null) return;
        try {
          await controller.push(repo);
          _setNotice(controller.l10n.mbPushed(repo.name));
        } on Object catch (error) {
          _setNotice(firstLine(controller.l10n, error), error: true);
        }
      case 'refresh':
        await controller.refreshAll();
      case 'openRepo':
        if (repo == null) return;
        await MenuBarBridge.showWindow();
        final navigator = _navigatorKey.currentState;
        if (navigator != null) openRepoWith(navigator, controller, repo);
      case 'openWindow':
        await MenuBarBridge.showWindow();
      case 'quit':
        await MenuBarBridge.quit();
    }
  }

  @override
  void dispose() {
    _pushTimer?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: _locale,
        builder: (context, locale, _) => MaterialApp(
          title: 'GIT Watcher',
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
        ),
      );
}
