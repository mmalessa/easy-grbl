import 'package:flutter/material.dart';
import '../focus_test.dart';
import '../../../../models/speed_unit.dart';
import 'test_panel_common.dart';

class FocusTestPanel extends StatelessWidget {
  final FocusTestConfig config;
  final ValueChanged<FocusTestConfig> onChanged;
  final VoidCallback onClose;
  final SpeedUnit speedUnit;

  const FocusTestPanel({
    super.key,
    required this.config,
    required this.onChanged,
    required this.onClose,
    required this.speedUnit,
  });

  @override
  Widget build(BuildContext context) {
    return TestPanelScaffold(
      icon: Icons.my_location,
      title: 'Focus Test',
      onClose: onClose,
      children: [
        const TestPanelLabel('Power'),
        const SizedBox(height: 4),
        TestPanelPowerSlider(
          value: config.powerPercent,
          onChanged: (v) => onChanged(config.copyWith(powerPercent: v)),
        ),
        const SizedBox(height: 12),
        TestPanelLabel('Speed (${speedUnit.label})'),
        const SizedBox(height: 4),
        TestPanelSpeedStepper(
          value: config.speedMmMin,
          unit: speedUnit,
          onChanged: (v) => onChanged(config.copyWith(speedMmMin: v)),
        ),
        const SizedBox(height: 16),
        TestPanelInfoRow('Width', '${config.widthMm.toInt()} mm'),
        TestPanelInfoRow('Lines', '${config.lineCount}'),
        TestPanelInfoRow('Z step', '${config.zStep.toStringAsFixed(1)} mm'),
        TestPanelInfoRow('Z range', '±${config.zRange.toStringAsFixed(1)} mm'),
      ],
    );
  }
}
