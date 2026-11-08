import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass.dart';

/// Runs a git action, shows a short toast when it works and the full git output when it fails.
Future<void> runWithFeedback(BuildContext context, Future<Object?> Function() action, {String? success}) async {
  try {
    final result = await action();
    if (!context.mounted) return;
    final text = success ?? _lastLine(result);
    if (text != null) toast(context, text);
  } on Object catch (error) {
    if (context.mounted) await showErrorDialog(context, error);
  }
}

String? _lastLine(Object? result) {
  if (result is List<String>) return result.isEmpty ? null : result.join(' · ');
  if (result is! String || result.trim().isEmpty) return null;
  return result.trim().split('\n').last.trim();
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text, maxLines: 4, overflow: TextOverflow.ellipsis)));
}

Future<void> showErrorDialog(BuildContext context, Object error) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded, color: Palette.red, size: 30),
        title: const Text('Þetta tókst ekki'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(child: SelectableText('$error', style: Txt.mono)),
        ),
        actions: [GlassButton(onPressed: () => Navigator.pop(context), label: 'Loka')],
      ),
    );

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required Widget body,
  required String action,
  IconData icon = Icons.help_outline_rounded,
  GlassTone tone = GlassTone.blue,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(icon, size: 30, color: tone.foreground),
      title: Text(title),
      content: SizedBox(width: 520, child: body),
      actions: [
        GlassButton(onPressed: () => Navigator.pop(context, false), label: 'Hætta við'),
        GlassButton(onPressed: () => Navigator.pop(context, true), label: action, tone: tone),
      ],
    ),
  );
  return answer ?? false;
}
