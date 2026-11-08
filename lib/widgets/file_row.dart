import 'package:flutter/material.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../theme.dart';

class KindBadge extends StatelessWidget {
  const KindBadge(this.kind, {super.key});

  final ChangeKind kind;

  @override
  Widget build(BuildContext context) {
    final color = Palette.kind(kind);
    return Container(
      width: 19,
      height: 19,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(5)),
      child: Text(kind.letter, style: Txt.strong.copyWith(fontSize: 10.5, color: color, height: 1)),
    );
  }
}

/// One changed file: optional checkbox, kind badge, name and folder, line counts.
class FileRow extends StatefulWidget {
  const FileRow({
    super.key,
    required this.file,
    required this.onTap,
    this.stat,
    this.selected = false,
    this.checked,
    this.onChecked,
    this.onContextMenu,
  });

  final FileChange file;
  final VoidCallback onTap;
  final LineStat? stat;
  final bool selected;
  final bool? checked;
  final VoidCallback? onChecked;
  final ValueChanged<Offset>? onContextMenu;

  @override
  State<FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<FileRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final stat = widget.stat;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: widget.onContextMenu == null ? null : (d) => widget.onContextMenu!(d.globalPosition),
        child: Container(
          height: 34,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: widget.selected ? const Color(0x2E1A6BB5) : (_hover ? const Color(0x14FFFFFF) : null),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(children: [
            if (widget.checked != null)
              SizedBox(
                width: 28,
                child: Checkbox(
                  value: widget.checked,
                  onChanged: (_) => widget.onChecked?.call(),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            KindBadge(file.kind),
            const SizedBox(width: 9),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: file.fileName, style: Txt.body.copyWith(fontWeight: FontWeight.w400)),
                  if (file.directory.isNotEmpty) TextSpan(text: '  ${file.directory}', style: Txt.muted.copyWith(fontSize: 11)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (stat != null) ...[
              const SizedBox(width: 6),
              if (stat.binary)
                Text('bin', style: Txt.muted.copyWith(fontSize: 11))
              else ...[
                if ((stat.added ?? 0) > 0)
                  Text('+${stat.added}', style: Txt.strong.copyWith(fontSize: 11, color: Palette.addedText)),
                if ((stat.deleted ?? 0) > 0) ...[
                  const SizedBox(width: 4),
                  Text('−${stat.deleted}', style: Txt.strong.copyWith(fontSize: 11, color: Palette.deletedText)),
                ],
              ],
            ],
          ]),
        ),
      ),
    );
  }
}
