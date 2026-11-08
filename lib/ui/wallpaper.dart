import 'package:flutter/material.dart';

/// Layered waves in the spirit of the macOS Big Sur wallpaper, in UteamUP colours,
/// with the UteamUP logo resting faintly behind the glass.
class Wallpaper extends StatelessWidget {
  const Wallpaper({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Stack(fit: StackFit.expand, children: [
          const RepaintBoundary(child: CustomPaint(painter: _WavePainter())),
          Align(
            alignment: const Alignment(.84, .7),
            child: Opacity(
              opacity: .16,
              child: Image.asset('assets/uteamup_logo.png', height: constraints.maxHeight * .62, filterQuality: FilterQuality.medium),
            ),
          ),
        ]),
      );
}

class _WavePainter extends CustomPainter {
  const _WavePainter();

  static const _w = 1600.0;
  static const _h = 1000.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _w > size.height / _h ? size.width / _w : size.height / _h;
    canvas
      ..translate((size.width - _w * scale) / 2, (size.height - _h * scale) / 2)
      ..scale(scale);

    const sky = Rect.fromLTWH(0, 0, _w, _h);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F6FC0), Color(0xFF5E9BDD), Color(0xFF9CC3EE)],
          stops: [0, .55, 1],
        ).createShader(sky),
    );

    _band(canvas, _wave(360, 640, 300, 960, 380, 1280, 460, 1420, 470, 400, cx1: 320, cy1: 250),
        const [Color(0xBF7FAEE6), Color(0xBF4F86CF)], horizontal: true);
    _band(canvas, _wave(430, 660, 380, 980, 470, 1300, 560, 1420, 560, 490, cx1: 330, cy1: 320),
        const [Color(0xFFFFFFFF), Color(0xFFD9E6F7)], horizontal: true);
    _band(canvas, _wave(500, 670, 460, 990, 560, 1310, 660, 1420, 660, 590, cx1: 320, cy1: 390),
        const [Color(0xFFFFE08A), Color(0xFFF9AD1B)], horizontal: true);
    _band(canvas, _wave(560, 640, 530, 970, 650, 1300, 770, 1400, 770, 700, cx1: 300, cy1: 440),
        const [Color(0xFFF9A25A), Color(0xFFF37321)]);

    final red = Path()
      ..moveTo(0, 290)
      ..cubicTo(190, 230, 400, 330, 580, 500)
      ..cubicTo(760, 670, 860, 830, 1120, 1000)
      ..lineTo(0, 1000)
      ..close();
    _band(canvas, red, const [Color(0xFFF26B4A), Color(0xFFEC3F5C), Color(0xFFC9327A)]);

    final violet = Path()
      ..moveTo(0, 720)
      ..cubicTo(160, 660, 320, 740, 450, 870)
      ..cubicTo(580, 1000, 560, 1000, 640, 1000)
      ..lineTo(0, 1000)
      ..close();
    _band(canvas, violet, const [Color(0xFFB23A8E), Color(0xFF5A3FA6)]);
  }

  /// A band from the left edge: one curve to the middle, a smooth second curve to the right edge.
  static Path _wave(double y0, double c2x, double c2y, double mx, double my, double s1x, double s1y, double s2x,
      double s2y, double endY,
      {required double cx1, required double cy1}) {
    return Path()
      ..moveTo(0, y0)
      ..cubicTo(cx1, cy1, c2x, c2y, mx, my)
      ..cubicTo(s1x, s1y, s2x, s2y, _w, endY)
      ..lineTo(_w, _h)
      ..lineTo(0, _h)
      ..close();
  }

  static void _band(Canvas canvas, Path path, List<Color> colors, {bool horizontal = false}) {
    final bounds = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: horizontal ? Alignment.centerLeft : Alignment.topLeft,
          end: horizontal ? Alignment.centerRight : Alignment.bottomRight,
          colors: colors,
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
