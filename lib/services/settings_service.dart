import 'package:shared_preferences/shared_preferences.dart';
import '../models/machine_settings.dart';

class SettingsService {
  static const _prefix = 'machine_';

  static Future<MachineSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return MachineSettings(
      machineType: MachineType.values.firstWhere(
        (m) => m.name == p.getString('${_prefix}machineType'),
        orElse: () => MachineType.laser,
      ),
      laserMode: LaserMode.values.firstWhere(
        (m) => m.name == p.getString('${_prefix}laserMode'),
        orElse: () => LaserMode.constant,
      ),
      sMax: p.getInt('${_prefix}sMax') ?? 1000,
      laserSpotSize: p.getDouble('${_prefix}laserSpotSize') ?? 0.1,
      maxSpindleSpeed: p.getInt('${_prefix}maxSpindleSpeed') ?? 24000,
      maxFeedRate: p.getDouble('${_prefix}maxFeedRate') ?? 3000.0,
      toolDiameter: p.getDouble('${_prefix}toolDiameter') ?? 3.175,
      bladeAngle: p.getDouble('${_prefix}bladeAngle') ?? 30.0,
      engravePower: p.getInt('${_prefix}engravePower') ?? 60,
      engraveSpeed: p.getInt('${_prefix}engraveSpeed') ?? 3000,
      cutPower: p.getInt('${_prefix}cutPower') ?? 100,
      cutSpeed: p.getInt('${_prefix}cutSpeed') ?? 800,
      fillPower: p.getInt('${_prefix}fillPower') ?? 80,
      fillSpeed: p.getInt('${_prefix}fillSpeed') ?? 3000,
      engraveSpindleSpeed: p.getInt('${_prefix}engraveSpindleSpeed') ?? 12000,
      engraveFeedRate: p.getDouble('${_prefix}engraveFeedRate') ?? 20.0,
      cutSpindleSpeed: p.getInt('${_prefix}cutSpindleSpeed') ?? 18000,
      cutFeedRate: p.getDouble('${_prefix}cutFeedRate') ?? 30.0,
      fillSpindleSpeed: p.getInt('${_prefix}fillSpindleSpeed') ?? 18000,
      fillFeedRate: p.getDouble('${_prefix}fillFeedRate') ?? 50.0,
      safeHeight: p.getDouble('${_prefix}safeHeight') ?? 5.0,
      travelFeedRate: p.getDouble('${_prefix}travelFeedRate') ?? 25.0,
      defaultBaudRate: p.getInt('${_prefix}defaultBaudRate') ?? 115200,
    );
  }

  static Future<void> save(MachineSettings s) async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setString('${_prefix}machineType', s.machineType.name),
      p.setString('${_prefix}laserMode', s.laserMode.name),
      p.setInt('${_prefix}sMax', s.sMax),
      p.setDouble('${_prefix}laserSpotSize', s.laserSpotSize),
      p.setInt('${_prefix}maxSpindleSpeed', s.maxSpindleSpeed),
      p.setDouble('${_prefix}maxFeedRate', s.maxFeedRate),
      p.setDouble('${_prefix}toolDiameter', s.toolDiameter),
      p.setDouble('${_prefix}bladeAngle', s.bladeAngle),
      p.setInt('${_prefix}engravePower', s.engravePower),
      p.setInt('${_prefix}engraveSpeed', s.engraveSpeed),
      p.setInt('${_prefix}cutPower', s.cutPower),
      p.setInt('${_prefix}cutSpeed', s.cutSpeed),
      p.setInt('${_prefix}fillPower', s.fillPower),
      p.setInt('${_prefix}fillSpeed', s.fillSpeed),
      p.setInt('${_prefix}engraveSpindleSpeed', s.engraveSpindleSpeed),
      p.setDouble('${_prefix}engraveFeedRate', s.engraveFeedRate),
      p.setInt('${_prefix}cutSpindleSpeed', s.cutSpindleSpeed),
      p.setDouble('${_prefix}cutFeedRate', s.cutFeedRate),
      p.setInt('${_prefix}fillSpindleSpeed', s.fillSpindleSpeed),
      p.setDouble('${_prefix}fillFeedRate', s.fillFeedRate),
      p.setDouble('${_prefix}safeHeight', s.safeHeight),
      p.setDouble('${_prefix}travelFeedRate', s.travelFeedRate),
      p.setInt('${_prefix}defaultBaudRate', s.defaultBaudRate),
    ]);
  }
}
