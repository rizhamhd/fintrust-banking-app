import 'package:flutter/material.dart';

/// Draws the original shaped glyph outlines exported by Figma. This preserves
/// font versions, kerning, mixed styles and line breaks while keeping text
/// semantics available. Editable values use regular Flutter TextFields.
class DesignGlyphs extends CustomPainter {
  DesignGlyphs(this.glyphs, this.paths);
  final List<dynamic> glyphs;
  final Map<String, Path> paths;

  static Map<String, Path> decode(Map<String, dynamic> data) => data.map((
    id,
    value,
  ) {
    final path = Path();
    for (final command in value as List) {
      final c = (command as List).map((n) => (n as num).toDouble()).toList();
      switch (c[0].toInt()) {
        case 0:
          path.close();
        case 1:
          path.moveTo(c[1], c[2]);
        case 2:
          path.lineTo(c[1], c[2]);
        case 3:
          path.quadraticBezierTo(c[1], c[2], c[3], c[4]);
        case 4:
          path.cubicTo(c[1], c[2], c[3], c[4], c[5], c[6]);
      }
    }
    return MapEntry(id, path);
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final g in glyphs) {
      final path = paths[g['path'].toString()];
      if (path == null) continue;
      final paint = Paint()
        ..color = Color(
          int.parse((g['color'] as String).replaceFirst('#', 'ff'), radix: 16),
        ).withValues(alpha: (g['opacity'] as num).toDouble());
      final scale = (g['size'] as num).toDouble();
      canvas.save();
      canvas.translate((g['x'] as num).toDouble(), (g['y'] as num).toDouble());
      canvas.scale(scale, -scale);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(DesignGlyphs oldDelegate) =>
      oldDelegate.glyphs != glyphs || oldDelegate.paths != paths;
}
