import 'package:flutter/material.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

/// Colours from the UteamUP logo, darkened where text has to sit on glass.
class Palette {
  static const ink = Color(0xFF1F2547);
  static const inkSoft = Color(0xFF424968);
  static const inkFaint = Color(0xFF8E94AA);
  static const blue = Color(0xFF1A6BB5);
  static const green = Color(0xFF16803F);
  static const rose = Color(0xFFC8264E);
  static const red = Color(0xFFD92F4F);
  static const amber = Color(0xFFE0920A);
  static const orange = Color(0xFFC2410C);
  static const violet = Color(0xFF5A3FA6);
  static const addedText = Color(0xFF14703A);
  static const deletedText = Color(0xFFC02848);

  static Color kind(ChangeKind kind) => switch (kind) {
        ChangeKind.modified => blue,
        ChangeKind.added => green,
        ChangeKind.deleted => const Color(0xFFE0344F),
        ChangeKind.renamed => violet,
        ChangeKind.untracked => amber,
        ChangeKind.conflicted => const Color(0xFFF37321),
      };

  static IconData kindIcon(ChangeKind kind) => switch (kind) {
        ChangeKind.modified => Icons.edit_rounded,
        ChangeKind.added => Icons.add_rounded,
        ChangeKind.deleted => Icons.delete_outline_rounded,
        ChangeKind.renamed => Icons.drive_file_rename_outline_rounded,
        ChangeKind.untracked => Icons.note_add_outlined,
        ChangeKind.conflicted => Icons.warning_amber_rounded,
      };

  /// Brand gradients for repositories without an icon of their own.
  static const repoGradients = [
    [Color(0xFF5FA8F0), Color(0xFF1A6BB5)],
    [Color(0xFF8C7BF0), Color(0xFF4B3FB0)],
    [Color(0xFFFF9A5A), Color(0xFFEC3F5C)],
    [Color(0xFF4FD1C5), Color(0xFF1A8C9C)],
    [Color(0xFF5BD27F), Color(0xFF1A8C45)],
    [Color(0xFFFFD25A), Color(0xFFF37321)],
    [Color(0xFF6E8BF5), Color(0xFF2A3480)],
    [Color(0xFFF58AC0), Color(0xFFB23A8E)],
  ];
}

class Txt {
  static const body = TextStyle(fontFamily: 'Roboto', fontSize: 12.5, fontWeight: FontWeight.w300, color: Palette.ink, height: 1.3);
  static const muted = TextStyle(fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.w300, color: Palette.inkSoft, height: 1.3);
  static const strong = TextStyle(fontFamily: 'Roboto', fontSize: 12.5, fontWeight: FontWeight.w500, color: Palette.ink, height: 1.3);
  static const title = TextStyle(fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w500, color: Palette.ink, height: 1.2);
  static const button = TextStyle(fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.w500, height: 1);
  static const mono = TextStyle(fontFamily: 'Menlo', fontSize: 12, height: 1.5, color: Palette.ink);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(seedColor: Palette.blue),
    scaffoldBackgroundColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.compact,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink).copyWith(
          bodyMedium: Txt.body,
          bodySmall: Txt.muted,
          labelLarge: Txt.strong,
        ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Palette.blue,
      selectionColor: Color(0x401A6BB5),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: const Color(0xEE1F2547), borderRadius: BorderRadius.circular(8)),
      textStyle: Txt.body.copyWith(color: Colors.white, fontSize: 12),
      waitDuration: const Duration(milliseconds: 500),
    ),
    menuTheme: MenuThemeData(style: glassMenuStyle),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xF4FAF8FC),
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: Txt.body.copyWith(fontSize: 13),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xF21F2547),
      contentTextStyle: Txt.body.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      width: 520,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: const BorderSide(color: Color(0x591F2547), width: 1),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.blue : const Color(0x80FFFFFF)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xF5F7F6FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: Txt.title.copyWith(fontSize: 17),
      contentTextStyle: Txt.body,
    ),
  );
}

final glassMenuStyle = MenuStyle(
  backgroundColor: const WidgetStatePropertyAll(Color(0xF4FAF8FC)),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  elevation: const WidgetStatePropertyAll(10),
  shadowColor: const WidgetStatePropertyAll(Color(0x663C1E50)),
  padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
    side: const BorderSide(color: Color(0x141F2547)),
  )),
);

final menuItemStyle = MenuItemButton.styleFrom(
  textStyle: Txt.body.copyWith(fontSize: 13),
  foregroundColor: Palette.ink,
  iconColor: Palette.inkSoft,
  iconSize: 17,
  minimumSize: const Size(220, 34),
  padding: const EdgeInsets.symmetric(horizontal: 10),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
).copyWith(
  backgroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.hovered) || s.contains(WidgetState.focused) ? const Color(0x1F1A6BB5) : null),
);
