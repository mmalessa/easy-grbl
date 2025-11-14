import 'package:xml/xml.dart';

class SvgPathParser {
  /// Wyciąga wszystkie ścieżki z atrybutu d="" w SVG
  static List<String> extractPaths(String svgContent) {
    final document = XmlDocument.parse(svgContent);
    final paths = <String>[];

    // Szukamy wszystkich elementów <path>
    for (final pathElement in document.findAllElements('path')) {
      final d = pathElement.getAttribute('d');
      if (d != null && d.trim().isNotEmpty) {
        paths.add(d.trim());
      }
    }

    return paths;
  }
}
