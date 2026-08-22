import 'package:flutter/material.dart';
import '../models/kerf_test_config.dart';
import 'test_panel_common.dart';

class KerfTestPanel extends StatelessWidget {
  final KerfTestConfig config;
  final ValueChanged<KerfTestConfig> onChanged;
  final VoidCallback onClose;

  const KerfTestPanel({
    super.key,
    required this.config,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TestPanelScaffold(
      icon: Icons.tune,
      title: 'Kerf Test',
      onClose: onClose,
      children: [
        const TestPanelLabel('Max power'),
        const SizedBox(height: 4),
        TestPanelPowerSlider(
          value: config.maxPowerPercent,
          min: 10,
          divisions: 90,
          onChanged: (v) => onChanged(config.copyWith(maxPowerPercent: v)),
        ),
        const SizedBox(height: 12),
        const TestPanelLabel('Speed (mm/min)'),
        const SizedBox(height: 4),
        TestPanelSpeedStepper(
          value: config.speedMmMin,
          onChanged: (v) => onChanged(config.copyWith(speedMmMin: v)),
        ),
        const SizedBox(height: 16),
        TestPanelInfoRow('Lines', '${config.lineCount}'),
        TestPanelInfoRow('Width', '${config.widthMm.toInt()} mm'),
        TestPanelInfoRow('Spacing', '${config.lineSpacing.toStringAsFixed(0)} mm'),
        TestPanelInfoRow('Max power', '${config.maxPowerPercent}%'),
        const SizedBox(height: 4),
        _powerLegend(cs),
      ],
    );
  }

  Widget _powerLegend(ColorScheme cs) {
    final levels = config.powerLevels;
    final colors = [
      Colors.green.shade300,
      Colors.yellow.shade600,
      Colors.orange.shade400,
      Colors.deepOrange.shade400,
      Colors.red.shade400,
      Colors.red.shade700,
    ];
    return Column(
      children: List.generate(levels.length, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 3,
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Line ${i + 1}  —  ${levels[i]}% power',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        );
      }),
    );
  }
}
