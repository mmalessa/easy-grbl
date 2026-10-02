import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/machines/machine_mode.dart';
import 'package:easy_grbl/machines/machine_settings.dart';
import 'package:easy_grbl/machines/mill/mill_settings.dart';
import 'package:easy_grbl/services/toolpath.dart';

import 'support/sample_document.dart';

// See gcode_regression_test.dart for how to regenerate goldens.
const _updateGoldens = bool.fromEnvironment('UPDATE_GOLDENS');

void _expectGolden(String name, String actual) {
  final file = File('test/goldens/$name');
  if (_updateGoldens) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(actual);
    return;
  }
  expect(actual, file.readAsStringSync());
}

/// Text dump of a toolpath: every contour sampled every 2 mm plus its end.
String _describe(ToolpathData? t) {
  if (t == null) return 'null';
  final b = StringBuffer();
  String fmt(Offset p) =>
      '${p.dx.toStringAsFixed(3)} ${p.dy.toStringAsFixed(3)}';
  void dump(String name, Path path) {
    b.writeln('# $name');
    for (final m in path.computeMetrics()) {
      b.writeln('contour len=${m.length.toStringAsFixed(3)}');
      for (var d = 0.0; d < m.length; d += 2.0) {
        final t = m.getTangentForOffset(d);
        if (t != null) b.writeln(fmt(t.position));
      }
      final end = m.getTangentForOffset(m.length);
      if (end != null) b.writeln('end ${fmt(end.position)}');
    }
  }

  dump('rapid', t.rapidPath);
  final colors = t.feeds.keys.toList()
    ..sort((a, c) => a.toARGB32().compareTo(c.toARGB32()));
  for (final c in colors) {
    dump('feed ${c.toARGB32().toRadixString(16)}', t.feeds[c]!);
  }
  return b.toString();
}

void main() {
  test('laser toolpath matches golden', () {
    _expectGolden('toolpath_laser.txt',
        _describe(computeToolpath(sampleDocument(), const MachineSettings())));
  });

  test('mill toolpath matches golden', () {
    _expectGolden(
        'toolpath_mill.txt',
        _describe(computeToolpath(sampleDocument(),
            const MachineSettings(
                machineType: MachineType.mill, mill: MillSettings(bladeAngle: 60)))));
  });
}
