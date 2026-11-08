import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// A saved language code the app can show, falling back to English.
Locale supportedLocale(String code) =>
    AppLocalizations.supportedLocales.firstWhere((l) => l.languageCode == code, orElse: () => const Locale('en'));
