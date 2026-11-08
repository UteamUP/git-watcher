import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Liquid Glass surface: blurred backdrop, white tint and an iridescent rim.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.tint = const Color(0x7AFFFFFF),
    this.blur = 26,
    this.shadow = true,
    this.rim = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color tint;
  final double blur;
  final bool shadow;
  final bool rim;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final panel = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(color: tint, borderRadius: borderRadius),
          child: CustomPaint(
            foregroundPainter: rim ? RimPainter(radius) : null,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
    if (!shadow) return panel;
    return CustomPaint(painter: _OuterShadowPainter(radius), child: panel);
  }
}

/// Shadow drawn only outside the panel, so it never darkens the glass itself.
class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas
      ..save()
      ..clipPath(Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Rect.fromLTWH(-60, -60, size.width + 120, size.height + 120))
        ..addRRect(rrect))
      ..drawRRect(
        rrect.shift(const Offset(0, 10)),
        Paint()
          ..color = const Color(0x293C1E50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) => old.radius != radius;
}

/// Iridescent edge plus a bright top sheen, like light caught in the rim of glass.
class RimPainter extends CustomPainter {
  const RimPainter(this.radius, {this.width = 1.2});

  final double radius;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(width / 2), Radius.circular((radius - width / 2).clamp(0, radius)));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = const SweepGradient(
          colors: [Color(0x99A5EBFF), Color(0xA6C8AAFF), Color(0x80FFBEE1), Color(0xE6FFF6C8), Color(0x99A5EBFF)],
          stops: [0, .15, .4, .62, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB3FFFFFF), Color(0x00FFFFFF)],
          stops: [0, .2],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(RimPainter old) => old.radius != radius || old.width != width;
}

/// Tinted glass colours for buttons. Text is a dark shade of the same hue so it always reads.
enum GlassTone {
  neutral(Color(0x80FFFFFF), Color(0x38FFFFFF), Color(0x1A1F2547), Color(0x241F2547), Palette.ink),
  green(Color(0x8078DC96), Color(0x5C1CA050), Color(0x4D16803F), Color(0x8C16803F), Color(0xFF063A1C)),
  blue(Color(0x8596C6F8), Color(0x5C1E68CE), Color(0x4D1B479A), Color(0x8C1B479A), Color(0xFF082A66)),
  rose(Color(0x85FFB280), Color(0x57EC3F5C), Color(0x4DC4264E), Color(0x8CEC3F5C), Color(0xFF610C27)),
  violet(Color(0x85C6B8FC), Color(0x526044B2), Color(0x475A3FA6), Color(0x735A3FA6), Color(0xFF28165F));

  const GlassTone(this.top, this.bottom, this.rim, this.glow, this.foreground);

  final Color top;
  final Color bottom;
  final Color rim;
  final Color glow;
  final Color foreground;
}

class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.onPressed,
    this.icon,
    this.label,
    this.tone = GlassTone.neutral,
    this.height = 34,
    this.radius = 11,
    this.expand = false,
    this.tooltip,
    this.iconColor,
    this.busy = false,
    this.trailing,
  });

  final IconData? trailing;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? label;
  final GlassTone tone;
  final double height;
  final double radius;
  final bool expand;
  final String? tooltip;
  final Color? iconColor;
  final bool busy;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  var _hover = false;
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final tone = widget.tone;
    final fg = enabled ? tone.foreground : Palette.inkFaint;
    final iconOnly = widget.label == null;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.busy)
          SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: tone.foreground))
        else if (widget.icon != null)
          Icon(widget.icon, size: iconOnly ? 17 : 16, color: enabled ? (widget.iconColor ?? fg) : Palette.inkFaint),
        if (!iconOnly && (widget.icon != null || widget.busy)) const SizedBox(width: 7),
        if (!iconOnly)
          Flexible(
            child: Text(widget.label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.button.copyWith(color: fg)),
          ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 6),
          Icon(widget.trailing, size: 15, color: enabled ? Palette.inkSoft : Palette.inkFaint),
        ],
      ],
    );

    Widget button = AnimatedScale(
      scale: _down ? .97 : 1,
      duration: const Duration(milliseconds: 90),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: widget.height,
        width: iconOnly ? widget.height : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? [_hover ? _lift(tone.top) : tone.top, _hover ? _lift(tone.bottom) : tone.bottom]
                : const [Color(0x47FFFFFF), Color(0x1FFFFFFF)],
          ),
          border: Border.all(color: enabled ? tone.rim : const Color(0x121F2547), width: .8),
          boxShadow: enabled
              ? [
                  BoxShadow(color: tone.glow, blurRadius: _hover ? 16 : 12, spreadRadius: -6, offset: const Offset(0, 5)),
                  const BoxShadow(color: Color(0x14141432), blurRadius: 1.5, offset: Offset(0, 1)),
                ]
              : null,
        ),
        // The sheen follows the button's own edge, so padding goes inside it.
        child: CustomPaint(
          painter: _ButtonSheenPainter(widget.radius, enabled),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : 13),
            child: Center(widthFactor: 1, child: content),
          ),
        ),
      ),
    );

    button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: Semantics(button: true, enabled: enabled, label: widget.label ?? widget.tooltip, child: button),
      ),
    );
    return widget.tooltip == null ? button : Tooltip(message: widget.tooltip!, child: button);
  }

  static Color _lift(Color c) => c.withValues(alpha: (c.a + .12).clamp(0, 1));
}

/// The thin bright top edge and faint iridescent sides of a macOS glass control.
class _ButtonSheenPainter extends CustomPainter {
  const _ButtonSheenPainter(this.radius, this.enabled);

  final double radius;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(.9), Radius.circular(radius - .9));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(enabled ? 0xD9FFFFFF : 0x8CFFFFFF), const Color(0x00FFFFFF)],
          stops: const [0, .45],
        ).createShader(rect),
    );
    if (!enabled) return;
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..shader = const LinearGradient(
          colors: [Color(0x80FFF8D2), Color(0x00FFFFFF), Color(0x00FFFFFF), Color(0x73C8AFFF)],
          stops: [0, .25, .75, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ButtonSheenPainter old) => old.radius != radius || old.enabled != enabled;
}

/// Inset macOS-style text field on glass.
class GlassField extends StatefulWidget {
  const GlassField({
    super.key,
    required this.controller,
    required this.hint,
    this.enabled = true,
    this.icon,
    this.suffix,
    this.onSubmitted,
    this.minLines = 1,
    this.maxLines = 1,
    this.obscure = false,
    this.onChanged,
  });

  final bool obscure;
  final ValueChanged<String>? onChanged;
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final IconData? icon;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final int minLines;
  final int maxLines;

  @override
  State<GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<GlassField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final multiLine = widget.maxLines > 1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: BoxConstraints(minHeight: multiLine ? 0 : 38),
      padding: EdgeInsets.fromLTRB(11, multiLine ? 9 : 0, widget.suffix == null ? 11 : 4, multiLine ? 9 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: !widget.enabled
              ? const [Color(0x26FFFFFF), Color(0x33FFFFFF)]
              : focused
                  ? const [Color(0x9EEFF2F8), Color(0xB3FFFFFF)]
                  : const [Color(0x7AE4E7F0), Color(0x6BFFFFFF)],
          stops: const [0, .45],
        ),
        border: Border.all(
          color: focused ? const Color(0x991A6BB5) : Color(widget.enabled ? 0x1F1F2547 : 0x121F2547),
          width: focused ? 1 : .8,
        ),
        boxShadow: focused ? const [BoxShadow(color: Color(0x381A6BB5), spreadRadius: 3.5)] : null,
      ),
      child: Row(
        crossAxisAlignment: multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 16, color: widget.enabled ? Palette.inkSoft : Palette.inkFaint),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              onSubmitted: widget.onSubmitted,
              onChanged: widget.onChanged,
              obscureText: widget.obscure,
              textAlignVertical: TextAlignVertical.center,
              style: Txt.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w400),
              decoration: InputDecoration.collapsed(
                hintText: widget.hint,
                hintStyle: Txt.body.copyWith(fontSize: 12.5, color: widget.enabled ? const Color(0xFF5F6683) : Palette.inkFaint),
              ),
            ),
          ),
          if (widget.suffix != null) ...[const SizedBox(width: 6), widget.suffix!],
        ],
      ),
    );
  }
}

/// Small rounded label with an icon, used for summary counts.
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0x0F1F2547), borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: Txt.body.copyWith(fontSize: 12)),
        ]),
      );
}
