import 'package:flutter/material.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../l10n/l10n.dart';
import '../theme.dart';

String noticeText(AppLocalizations l, DiffNotice notice) => switch (notice) {
      DiffNotice.binary => l.repoNoticeBinary,
      DiffNotice.missing => l.repoNoticeMissing,
      DiffNotice.directory => l.repoNoticeDirectory,
      DiffNotice.tooLarge => l.repoNoticeTooLarge,
      DiffNotice.empty => l.repoNoticeEmpty,
      DiffNotice.none => '',
    };

/// Unified diff with old and new line numbers, green additions and red removals.
class DiffView extends StatelessWidget {
  const DiffView({super.key, required this.diff});

  final FileDiff diff;

  @override
  Widget build(BuildContext context) {
    if (diff.notice != DiffNotice.none) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.info_outline_rounded, size: 34, color: Palette.inkSoft),
          const SizedBox(height: 10),
          Text(noticeText(context.l10n, diff.notice), style: Txt.muted.copyWith(fontSize: 13)),
        ]),
      );
    }
    final lines = diff.lines;
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: lines.length + (diff.truncated ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == lines.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.l10n.repoDiffTruncated(lines.length), style: Txt.muted),
            );
          }
          return _DiffRow(lines[i]);
        },
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow(this.line);

  final DiffLine line;

  @override
  Widget build(BuildContext context) {
    if (line.type == DiffLineType.hunk) {
      return Container(
        margin: const EdgeInsets.only(top: 6, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        color: const Color(0x145A3FA6),
        child: Text(line.text, style: Txt.mono.copyWith(fontSize: 11.5, color: Palette.violet)),
      );
    }
    final (Color? background, Color foreground, String sign) = switch (line.type) {
      DiffLineType.added => (const Color(0x2922B04B), const Color(0xFF0E5A2C), '+'),
      DiffLineType.removed => (const Color(0x29EC3F5C), const Color(0xFF8E1838), '−'),
      DiffLineType.note => (null, Palette.inkSoft, ''),
      _ => (null, Palette.ink, ''),
    };
    final number = Txt.mono.copyWith(fontSize: 11, color: Palette.inkFaint);
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectionContainer.disabled(
          child: Row(children: [
            SizedBox(width: 42, child: Text('${line.oldLine ?? ''}', textAlign: TextAlign.right, style: number)),
            SizedBox(width: 42, child: Text('${line.newLine ?? ''}', textAlign: TextAlign.right, style: number)),
            SizedBox(width: 22, child: Text(sign, textAlign: TextAlign.center, style: Txt.mono.copyWith(color: foreground))),
          ]),
        ),
        Expanded(
          child: Text(
            line.text.replaceAll('\t', '    '),
            style: Txt.mono.copyWith(color: foreground, fontStyle: line.type == DiffLineType.note ? FontStyle.italic : null),
          ),
        ),
      ]),
    );
  }
}
