import 'dart:ui';
import 'svg_path_model.dart';

class SvgPathParser {
  /// Wyciąga wszystkie ścieżki z SVG i zwraca listę modeli z id i d
  static List<SvgPathModel> extractPaths(String svgContent) {
    final paths = <SvgPathModel>[];

    // parsowanie path
    final RegExp pathRegExp =
      RegExp(
        r'<path\b[^>]*\bid="([^"]+)"[^>]*\bd="([^"]+)"|<path\b[^>]*\bd="([^"]+)"[^>]*\bid="([^"]+)"',
        multiLine: true
      );
    final matches = pathRegExp.allMatches(svgContent);
    for (final m in matches) {
      // Sprawdź która kombinacja została złapana
      final id = m.group(1) ?? m.group(4) ?? 'unknown';
      final d = m.group(2) ?? m.group(3) ?? '';
      if (d.isEmpty) continue;
      paths.add(SvgPathModel(id: id, d: _fixPath(d)));
    }

    // parsowanie rect
    final RegExp rectRegExp =
      RegExp(
        r'<rect\b[^>]*\bid="([^"]+)"[^>]*\bwidth="([^"]+)"[^>]*\bheight="([^"]+)"[^>]*\bx="([^"]+)"[^>]*\by="([^"]+)"',
        multiLine: true
      );
    final rectMatches = rectRegExp.allMatches(svgContent);
    for (final m in rectMatches) {
      final id = m.group(1) ?? 'unknown';
      final width = double.tryParse(m.group(2)!) ?? 0;
      final height = double.tryParse(m.group(3)!) ?? 0;
      final x = double.tryParse(m.group(4)!) ?? 0;
      final y = double.tryParse(m.group(5)!) ?? 0;

      // Konwersja rect na d
      final d = 'M$x,$y h$width v$height h-${width} z';
      paths.add(SvgPathModel(id: id, d: d));
    }

    return paths;
  }

  /// Jeśli ścieżka nie zaczyna się od M lub m, dodaj M0,0 na początek
  static String _fixPath(String d) {
    final trimmed = d.trim();
    if (trimmed.isEmpty) return trimmed;

    if (!trimmed.startsWith(RegExp(r'[Mm]'))) {
      return 'M0,0 $trimmed';
    }
    return trimmed;
  }

  /// Pobiera viewBox z SVG, np. "0 0 16 16"
  static Rect extractViewBox(String svgContent) {
    final RegExp viewBoxRegExp = RegExp(r'viewBox="([^"]+)"');
    final match = viewBoxRegExp.firstMatch(svgContent);
    if (match != null) {
      final parts = match.group(1)!
          .split(RegExp(r'\s+'))
          .map((e) => double.tryParse(e) ?? 0)
          .toList();
      if (parts.length == 4) {
        return Rect.fromLTWH(parts[0], parts[1], parts[2], parts[3]);
      }
    }
    return Rect.fromLTWH(0, 0, 100, 100); // domyślny
  }
}
