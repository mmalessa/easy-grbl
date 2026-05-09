import 'package:flutter/material.dart';
import '../models/svg_node.dart';
import '../models/svg_node_type.dart';
import '../models/layer_settings.dart';
import '../models/operation_type.dart';

class LayerSettingsPanel extends StatefulWidget {
  final SvgNode node;
  final void Function(LayerSettings) onChanged;

  const LayerSettingsPanel({
    super.key,
    required this.node,
    required this.onChanged,
  });

  @override
  State<LayerSettingsPanel> createState() => _LayerSettingsPanelState();
}

class _LayerSettingsPanelState extends State<LayerSettingsPanel> {
  late OperationType _opType;
  late double _power;
  late int _speed;
  late int _passes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LayerSettingsPanel old) {
    super.didUpdateWidget(old);
    if (old.node.id != widget.node.id) setState(_load);
  }

  void _load() {
    _opType = widget.node.settings.operationType;
    _power = widget.node.settings.powerPercent.toDouble();
    _speed = widget.node.settings.speedMmMin;
    _passes = widget.node.settings.passes;
  }

  void _emit() => widget.onChanged(LayerSettings(
        operationType: _opType,
        powerPercent: _power.round(),
        speedMmMin: _speed,
        passes: _passes,
      ));

  @override
  Widget build(BuildContext context) {
    final color = _opType.color;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Node label
          Row(children: [
            Icon(_nodeIcon(widget.node.type), size: 13, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.node.label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // Operation type
          _label('Operation'),
          const SizedBox(height: 4),
          _OpTypePicker(
            value: _opType,
            onChanged: (v) {
              setState(() => _opType = v);
              _emit();
            },
          ),
          const SizedBox(height: 12),

          // Power
          Row(
            children: [
              _label('Power'),
              const Spacer(),
              Text(
                '${_power.round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
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
            child: SizedBox(
              height: 28,
              child: Slider(
                value: _power,
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: (v) {
                  setState(() => _power = v);
                  _emit();
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Speed
          _label('Speed (mm/min)'),
          const SizedBox(height: 4),
          _Counter(
            value: _speed,
            step: 100,
            min: 10,
            max: 30000,
            accentColor: color,
            onChanged: (v) {
              setState(() => _speed = v);
              _emit();
            },
          ),
          const SizedBox(height: 10),

          // Passes
          _label('Passes'),
          const SizedBox(height: 4),
          _Counter(
            value: _passes,
            step: 1,
            min: 1,
            max: 20,
            accentColor: color,
            onChanged: (v) {
              setState(() => _passes = v);
              _emit();
            },
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(fontSize: 10, color: Colors.grey[600], letterSpacing: 0.5),
      );

  IconData _nodeIcon(SvgNodeType t) => switch (t) {
        SvgNodeType.layer => Icons.layers,
        SvgNodeType.group => Icons.folder_open_outlined,
        _ => Icons.gesture,
      };
}

// ---------------------------------------------------------------------------

class _OpTypePicker extends StatelessWidget {
  final OperationType value;
  final void Function(OperationType) onChanged;

  const _OpTypePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: OperationType.values
          .map((t) => Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(t),
                  child: Container(
                    margin: const EdgeInsets.only(right: 3),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: t == value
                          ? t.color.withValues(alpha: 0.15)
                          : Colors.grey[100],
                      border: Border.all(
                        color: t == value ? t.color : Colors.grey[300]!,
                        width: t == value ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: t == value ? FontWeight.w700 : FontWeight.normal,
                        color: t == value ? t.color : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------

class _Counter extends StatelessWidget {
  final int value;
  final int step;
  final int min;
  final int max;
  final Color accentColor;
  final void Function(int) onChanged;

  const _Counter({
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _btn(Icons.remove, value > min ? () => onChanged((value - step).clamp(min, max)) : null),
        Expanded(
          child: Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        _btn(Icons.add, value < max ? () => onChanged((value + step).clamp(min, max)) : null),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: 28,
      height: 26,
      child: Material(
        color: onTap != null ? accentColor.withValues(alpha: 0.12) : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Icon(
            icon,
            size: 13,
            color: onTap != null ? accentColor : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
