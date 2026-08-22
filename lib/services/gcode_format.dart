/// Formats a numeric value for G-code output — fixed to 3 decimal places.
String formatGcodeNumber(double v) => v.toStringAsFixed(3);

/// Splits G-code text into executable lines: strips inline `;` comments,
/// trims whitespace, and drops blank lines.
List<String> stripGcodeComments(String gcode) => gcode
    .split('\n')
    .map((l) => l.contains(';')
        ? l.substring(0, l.indexOf(';')).trim()
        : l.trim())
    .where((l) => l.isNotEmpty)
    .toList();
