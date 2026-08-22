import 'package:shared_preferences/shared_preferences.dart';
import '../models/machine_settings.dart';

/// Persists [MachineSettings] to [SharedPreferences] as a flat set of
/// `machine_<field>` keys, driven entirely by [MachineSettings.toMap] and
/// [MachineSettings.fromMap] — this class never lists individual field
/// names, so a field added to [MachineSettings] is automatically saved and
/// loaded without touching this file.
class SettingsService {
  static const _prefix = 'machine_';

  static Future<MachineSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final map = <String, Object?>{
      for (final key in p.getKeys())
        if (key.startsWith(_prefix)) key.substring(_prefix.length): p.get(key),
    };
    return MachineSettings.fromMap(map);
  }

  static Future<void> save(MachineSettings s) async {
    final p = await SharedPreferences.getInstance();
    await Future.wait(s.toMap().entries.map((e) {
      final key = '$_prefix${e.key}';
      final value = e.value;
      return switch (value) {
        String v => p.setString(key, v),
        int v => p.setInt(key, v),
        double v => p.setDouble(key, v),
        _ => throw StateError(
            'Unsupported MachineSettings value type for $key: ${value.runtimeType}'),
      };
    }));
  }
}
