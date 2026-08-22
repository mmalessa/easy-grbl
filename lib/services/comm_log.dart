import 'package:flutter/foundation.dart';

typedef LogEntry = ({bool rx, String text});

/// Rolling TX/RX communication log, capped at 500 entries — separate from
/// machine pose/status and job-in-progress state.
class CommLog {
  CommLog(this._onChange);

  final VoidCallback _onChange;
  final List<LogEntry> entries = [];

  void tx(String text) => _add(rx: false, text: text);
  void rx(String text) => _add(rx: true, text: text);

  void _add({required bool rx, required String text}) {
    entries.add((rx: rx, text: text));
    if (entries.length > 500) entries.removeAt(0);
    _onChange();
  }
}
