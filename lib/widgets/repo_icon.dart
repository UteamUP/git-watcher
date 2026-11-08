import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';
import '../ui/glass.dart';

/// Frosted rounded tile that holds an icon, like the icons in macOS Liquid Glass.
class GlassTile extends StatelessWidget {
  const GlassTile({super.key, required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = size * .3;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xEBFFFFFF), Color(0x94FFFFFF)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x293C1E50), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: CustomPaint(foregroundPainter: RimPainter(radius, width: 1), child: Center(child: child)),
    );
  }
}

/// The project's own icon, or a colourful glyph picked from its name.
class RepoIcon extends StatelessWidget {
  const RepoIcon({super.key, required this.name, required this.iconPath, this.size = 42});

  final String name;
  final String? iconPath;
  final double size;

  @override
  Widget build(BuildContext context) => GlassTile(size: size, child: _image());

  Widget _image() {
    final path = iconPath;
    final glyph = _glyph();
    if (path == null) return glyph;
    final inner = size * .66;
    if (path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.file(File(path), width: inner, height: inner, placeholderBuilder: (_) => glyph);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .2),
      child: Image.file(File(path), width: inner, height: inner, fit: BoxFit.contain, errorBuilder: (_, _, _) => glyph),
    );
  }

  Widget _glyph() {
    final colors = Palette.repoGradients[name.toLowerCase().codeUnits.fold(0, (a, b) => a + b) % Palette.repoGradients.length];
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors).createShader(rect),
      child: Icon(
        glyphFor(name),
        size: size * .56,
        color: Colors.white,
        shadows: [Shadow(color: colors.last.withValues(alpha: .45), blurRadius: 5, offset: const Offset(0, 3))],
      ),
    );
  }
}

/// The UteamUP logo on a glass tile, used as the app's own mark.
class LogoTile extends StatelessWidget {
  const LogoTile({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) =>
      GlassTile(size: size, child: Image.asset('assets/logo.png', height: size * .66, filterQuality: FilterQuality.medium));
}

const _glyphs = <String, IconData>{
  'backend': Icons.dns_rounded,
  'api': Icons.dns_rounded,
  'frontend': Icons.dashboard_rounded,
  'website': Icons.language_rounded,
  'web': Icons.language_rounded,
  'mobile': Icons.phone_iphone_rounded,
  'watch': Icons.watch_rounded,
  'desktop': Icons.desktop_mac_rounded,
  'cli': Icons.terminal_rounded,
  'mcp': Icons.hub_rounded,
  'icon': Icons.category_rounded,
  'infra': Icons.cloud_rounded,
  'pulse': Icons.monitor_heart_rounded,
  'pentest': Icons.security_rounded,
  'security': Icons.security_rounded,
  'onboarding': Icons.rocket_launch_rounded,
  'lager': Icons.warehouse_rounded,
  'homey': Icons.home_rounded,
  'home': Icons.home_rounded,
  'iot': Icons.sensors_rounded,
  'edge': Icons.router_rounded,
  'extension': Icons.extension_rounded,
  'browser': Icons.public_rounded,
  'connector': Icons.cable_rounded,
  'brand': Icons.palette_rounded,
  'wallpaper': Icons.wallpaper_rounded,
  'doc': Icons.description_rounded,
  'test': Icons.science_rounded,
  'git': Icons.merge_rounded,
  'project': Icons.folder_special_rounded,
};

IconData glyphFor(String name) {
  final lower = name.toLowerCase();
  for (final entry in _glyphs.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return Icons.folder_rounded;
}
