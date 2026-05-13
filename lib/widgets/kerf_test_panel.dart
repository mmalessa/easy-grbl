import 'package:flutter/material.dart';
import '../models/kerf_test_config.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Max power'),
                const SizedBox(height: 4),
                _powerSlider(),
                const SizedBox(height: 12),
                _label('Speed (mm/min)'),
                const SizedBox(height: 4),
                _speedStepper(),
                const SizedBox(height: 16),
                _infoRow('Lines', '${config.lineCount}'),
                _infoRow('Width', '${config.widthMm.toInt()} mm'),
                _infoRow('Spacing', '${config.lineSpacing.toStringAsFixed(0)} mm'),
                _infoRow('Max power', '${config.maxPowerPercent}%'),
                const SizedBox(height: 4),
                _powerLegend(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          const Icon(Icons.tune, size: 14, color: Color(0xFF89B4FA)),
          const SizedBox(width: 6),
          const Text(
            'Kerf Test',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 10, color: Colors.grey[600], letterSpacing: 0.5),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _label(label),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _powerSlider() {
    final color = Colors.red.shade400;
    final pct = config.maxPowerPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            Text(
              '$pct%',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.15),
            inactiveTrackColor: Colors.grey[300],
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: pct.toDouble(),
            min: 10,
            max: 100,
            divisions: 90,
            onChanged: (v) =>
                onChanged(config.copyWith(maxPowerPercent: v.round())),
          ),
        ),
      ],
    );
  }

  Widget _powerLegend() {
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
                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _speedStepper() {
    return Row(
      children: [
        _speedBtn(Icons.remove, () {
          final v = (config.speedMmMin - 100).clamp(100, 30000);
          onChanged(config.copyWith(speedMmMin: v));
        }),
        Expanded(
          child: Text(
            '${config.speedMmMin}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        _speedBtn(Icons.add, () {
          final v = (config.speedMmMin + 100).clamp(100, 30000);
          onChanged(config.copyWith(speedMmMin: v));
        }),
      ],
    );
  }

  Widget _speedBtn(IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: 32,
      height: 28,
      child: Material(
        color: onTap != null
            ? Colors.orange.withValues(alpha: 0.12)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Icon(
            icon,
            size: 14,
            color: onTap != null ? Colors.orange : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
