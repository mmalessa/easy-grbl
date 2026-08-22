import 'package:flutter/material.dart';
import '../models/focus_test_config.dart';
import 'test_panel_common.dart';

class FocusTestPanel extends StatelessWidget {
  final FocusTestConfig config;
  final ValueChanged<FocusTestConfig> onChanged;
  final VoidCallback onClose;

  const FocusTestPanel({
    super.key,
    required this.config,
    required this.onChanged,
    required this.onClose,
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
        const TestPanelLabel('Speed (mm/min)'),
        const SizedBox(height: 4),
        TestPanelSpeedStepper(
          value: config.speedMmMin,
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
