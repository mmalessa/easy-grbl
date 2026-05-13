import 'package:flutter/material.dart';
import '../models/spot_test_config.dart';

class SpotTestPanel extends StatelessWidget {
  final SpotTestConfig config;
  final double spotSize;
  final ValueChanged<SpotTestConfig> onChanged;
  final VoidCallback onClose;

  const SpotTestPanel({
    super.key,
    required this.config,
    required this.spotSize,
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
                _label('Power'),
                const SizedBox(height: 4),
                _powerSlider(),
                const SizedBox(height: 12),
                _label('Speed (mm/min)'),
                const SizedBox(height: 4),
                _speedStepper(),
                const SizedBox(height: 16),
                _infoRow('Square', '9 × 9 mm'),
                _infoRow('Laser spot', '${spotSize.toStringAsFixed(2)} mm'),
                const SizedBox(height: 8),
                _legend(),
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
          const Icon(Icons.grid_on, size: 14, color: Color(0xFF89B4FA)),
          const SizedBox(width: 6),
          const Text(
            'Spot Size Test',
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

  Widget _legend() {
    final bands = [
      ('Top', 'spot size + 0.1 mm', Colors.red.shade300),
      ('Middle', 'spot size (exact)', Colors.green.shade400),
      ('Bottom', 'spot size − 0.1 mm', Colors.blue.shade300),
    ];
    return Column(
      children: bands.map((b) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: b.$3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${b.$1} — ${b.$2}',
                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _powerSlider() {
    final color = Colors.orange.shade400;
    final pct = config.powerPercent;
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
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: (v) =>
                onChanged(config.copyWith(powerPercent: v.round())),
          ),
        ),
      ],
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
