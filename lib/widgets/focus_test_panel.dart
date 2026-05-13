import 'package:flutter/material.dart';
import '../models/focus_test_config.dart';

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
                _infoRow('Width', '${config.widthMm.toInt()} mm'),
                _infoRow('Lines', '${config.lineCount}'),
                _infoRow('Z step', '${config.zStep.toStringAsFixed(1)} mm'),
                _infoRow('Z range', '±${config.zRange.toStringAsFixed(1)} mm'),
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
          const Icon(Icons.my_location, size: 14, color: Color(0xFF89B4FA)),
          const SizedBox(width: 6),
          const Text(
            'Focus Test',
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
    final color = Colors.orange.shade400;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            Text(
              '${config.powerPercent}%',
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
            value: config.powerPercent.toDouble(),
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
