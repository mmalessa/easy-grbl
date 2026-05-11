import 'package:shared_preferences/shared_preferences.dart';
import '../models/machine_settings.dart';

class SettingsService {
  static const _prefix = 'machine_';

  static Future<MachineSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return MachineSettings(
      laserMode: LaserMode.values.firstWhere(
        (m) => m.name == p.getString('${_prefix}laserMode'),
        orElse: () => LaserMode.constant,
      ),
      sMax: p.getInt('${_prefix}sMax') ?? 1000,
      laserSpotSize: p.getDouble('${_prefix}laserSpotSize') ?? 0.1,
      engravePower: p.getInt('${_prefix}engravePower') ?? 60,
      engraveSpeed: p.getInt('${_prefix}engraveSpeed') ?? 3000,
      cutPower: p.getInt('${_prefix}cutPower') ?? 100,
      cutSpeed: p.getInt('${_prefix}cutSpeed') ?? 800,
      defaultBaudRate: p.getInt('${_prefix}defaultBaudRate') ?? 115200,
    );
  }

  static Future<void> save(MachineSettings s) async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setString('${_prefix}laserMode', s.laserMode.name),
      p.setInt('${_prefix}sMax', s.sMax),
      p.setDouble('${_prefix}laserSpotSize', s.laserSpotSize),
      p.setInt('${_prefix}engravePower', s.engravePower),
      p.setInt('${_prefix}engraveSpeed', s.engraveSpeed),
      p.setInt('${_prefix}cutPower', s.cutPower),
      p.setInt('${_prefix}cutSpeed', s.cutSpeed),
      p.setInt('${_prefix}defaultBaudRate', s.defaultBaudRate),
    ]);
  }
}
