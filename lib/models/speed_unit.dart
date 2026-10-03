import 'package:flutter/widgets.dart';

/// Unit in which speeds / feed rates are shown and entered in the UI.
/// Purely a display preference — stored values keep their own units
/// (layer speeds and mill feeds in mm/s, laser defaults in mm/min).
enum SpeedUnit {
  mmPerSec('mm/s', 1),
  mmPerMin('mm/min', 60);

  final String label;
  final double _perMmS;

  const SpeedUnit(this.label, this._perMmS);

  double fromMmS(double mmS) => mmS * _perMmS;
  double toMmS(double v) => v / _perMmS;

  /// mm/s shown with one decimal, mm/min as a whole number.
  String format(double v) => this == SpeedUnit.mmPerSec
      ? v.toStringAsFixed(1)
      : v.round().toString();
}

/// Text controller for a speed field that holds its value in mm/s and shows
/// it in [unit]. As long as the text is not edited, [mmS] returns the
/// original value exactly, so formatting round-off never alters saved data.
class SpeedTextController extends TextEditingController {
  SpeedTextController(this._original, this._unit)
      : super(text: _unit.format(_unit.fromMmS(_original)));

  final double _original;
  SpeedUnit _unit;

  SpeedUnit get unit => _unit;

  /// Switches the display unit, converting the current text.
  set unit(SpeedUnit u) {
    if (u == _unit) return;
    final v = mmS;
    _unit = u;
    if (v != null) text = u.format(u.fromMmS(v));
  }

  /// Current value in mm/s, or null when the text is not a positive number.
  double? get mmS {
    if (text == _unit.format(_unit.fromMmS(_original))) return _original;
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0) return null;
    return _unit.toMmS(v);
  }

  /// Steps the value by [delta] (in the display unit), clamped to
  /// [minMmS]..[maxMmS].
  void nudge(double delta, double minMmS, double maxMmS) {
    final cur = _unit.fromMmS(mmS ?? minMmS);
    final next = _unit.toMmS(cur + delta).clamp(minMmS, maxMmS);
    text = _unit.format(_unit.fromMmS(next));
  }
}
