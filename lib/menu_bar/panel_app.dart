import 'package:flutter/material.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'panel_page.dart';

/// The app inside the menu bar panel.
///
/// It is a second Flutter engine with no state of its own: the main app pushes a snapshot into
/// it and the panel sends actions back, so both always show the same thing.
class MenuBarPanelApp extends StatelessWidget {
  const MenuBarPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = supportedLocale(WatcherConfig.load().language);
    return MaterialApp(
      title: 'GIT Watcher',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.02)),
        child: child!,
      ),
      home: const MenuBarPanelPage(),
    );
  }
}
