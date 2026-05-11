import 'package:flutter/material.dart';
import '../models/svg_node.dart';
import '../models/svg_node_type.dart';
import '../models/layer_settings.dart';
import '../models/machine_settings.dart';
import '../models/operation_type.dart';

class LayerSettingsPanel extends StatefulWidget {
  final SvgNode node;
  final MachineSettings machineSettings;
  final void Function(LayerSettings) onChanged;

  const LayerSettingsPanel({
    super.key,
    required this.node,
    required this.machineSettings,
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
  late FillDirection _fillDirection;
  late double _linesPerMm;

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
    final s = widget.node.settings;
    _opType = s.operationType;
    _power = s.powerPercent.toDouble();
    _speed = s.speedMmMin;
    _passes = s.passes;
    _fillDirection = s.fillDirection;
    _linesPerMm = s.linesPerMm;
  }

  void _emit() => widget.onChanged(LayerSettings(
        operationType: _opType,
        powerPercent: _power.round(),
        speedMmMin: _speed,
        passes: _passes,
        fillDirection: _fillDirection,
        linesPerMm: _linesPerMm,
      ));

  double get _autoLinesPerMm {
    final spot = widget.machineSettings.laserSpotSize;
    return spot > 0 ? 1.0 / spot : 10.0;
  }

  @override
  Widget build(BuildContext context) {
    final color = _opType == OperationType.skip
        ? Colors.grey
        : _opType.color;
    final isFill = _opType == OperationType.fill;

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
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
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
              setState(() {
                _opType = v;
                final ms = widget.machineSettings;
                if (v == OperationType.engrave) {
                  _power = ms.engravePower.toDouble();
                  _speed = ms.engraveSpeed;
                } else if (v == OperationType.cut) {
                  _power = ms.cutPower.toDouble();
                  _speed = ms.cutSpeed;
                } else if (v == OperationType.fill) {
                  _power = ms.fillPower.toDouble();
                  _speed = ms.fillSpeed;
                  _linesPerMm = _autoLinesPerMm;
                }
              });
              _emit();
            },
          ),
          const SizedBox(height: 12),

          // Power
          Row(children: [
            _label('Power'),
            const Spacer(),
            Text(
              '${_power.round()}%',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
          ]),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
              inactiveTrackColor: Colors.grey[300],
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
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

          // Passes (hidden for Fill)
          if (!isFill) ...[
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
            const SizedBox(height: 10),
          ],

          // Fill-specific settings
          if (isFill) ...[
            const Divider(height: 16, thickness: 1, color: Color(0xFFEEEEEE)),
            _label('Direction'),
            const SizedBox(height: 4),
            _DirectionPicker(
              value: _fillDirection,
              color: color,
              onChanged: (v) {
                setState(() => _fillDirection = v);
                _emit();
              },
            ),
            const SizedBox(height: 10),
            Row(children: [
              _label('Lines/mm'),
              const Spacer(),
              Text(
                _linesPerMm == _autoLinesPerMm ? 'auto' : '',
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic),
              ),
            ]),
            const SizedBox(height: 4),
            _LinesPerMmCounter(
              value: _linesPerMm,
              autoValue: _autoLinesPerMm,
              color: color,
              onChanged: (v) {
                setState(() => _linesPerMm = v);
                _emit();
              },
              onReset: () {
                setState(() => _linesPerMm = _autoLinesPerMm);
                _emit();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
            fontSize: 10, color: Colors.grey[600], letterSpacing: 0.5),
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
    const ops = [OperationType.engrave, OperationType.cut, OperationType.fill];
    return Row(
      children: [
        // Clear button — always single-state, sets operation to skip
        GestureDetector(
          onTap: () => onChanged(OperationType.skip),
          child: Container(
            width: 26,
            margin: const EdgeInsets.only(right: 3),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey[300]!, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.close, size: 10, color: Colors.grey[500]),
          ),
        ),
        ...ops.map((t) => Expanded(
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
                      fontWeight:
                          t == value ? FontWeight.w700 : FontWeight.normal,
                      color: t == value ? t.color : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _DirectionPicker extends StatelessWidget {
  final FillDirection value;
  final Color color;
  final void Function(FillDirection) onChanged;

  const _DirectionPicker({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: FillDirection.values.map((d) {
        final sel = d == value;
        final label = d == FillDirection.horizontal ? 'Horizontal' : 'Vertical';
        final icon = d == FillDirection.horizontal
            ? Icons.horizontal_rule
            : Icons.more_vert;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(d),
            child: Container(
              margin: const EdgeInsets.only(right: 3),
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: sel ? color.withValues(alpha: 0.15) : Colors.grey[100],
                border: Border.all(
                  color: sel ? color : Colors.grey[300]!,
                  width: sel ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 12,
                      color: sel ? color : Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          sel ? FontWeight.w700 : FontWeight.normal,
                      color: sel ? color : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------

class _LinesPerMmCounter extends StatelessWidget {
  final double value;
  final double autoValue;
  final Color color;
  final void Function(double) onChanged;
  final VoidCallback onReset;

  const _LinesPerMmCounter({
    required this.value,
    required this.autoValue,
    required this.color,
    required this.onChanged,
    required this.onReset,
  });

  static double _step(double v) => v >= 10 ? 1.0 : 0.5;

  @override
  Widget build(BuildContext context) {
    final step = _step(value);
    return Row(
      children: [
        _btn(Icons.remove, value > 0.5 ? () => onChanged((value - step).clamp(0.5, 100.0)) : null),
        Expanded(
          child: Text(
            value == value.roundToDouble()
                ? value.toInt().toString()
                : value.toStringAsFixed(1),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        _btn(Icons.add, value < 100 ? () => onChanged((value + step).clamp(0.5, 100.0)) : null),
        const SizedBox(width: 6),
        SizedBox(
          width: 36,
          height: 26,
          child: Tooltip(
            message: 'Reset to auto (${autoValue.toStringAsFixed(1)})',
            child: Material(
              color: value == autoValue
                  ? color.withValues(alpha: 0.12)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                onTap: onReset,
                borderRadius: BorderRadius.circular(4),
                child: Icon(
                  Icons.autorenew,
                  size: 13,
                  color: value == autoValue ? color : Colors.grey[400],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) => SizedBox(
        width: 28,
        height: 26,
        child: Material(
          color: onTap != null ? color.withValues(alpha: 0.12) : Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Icon(icon,
                size: 13,
                color: onTap != null ? color : Colors.grey[400]),
          ),
        ),
      );
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
        _btn(Icons.remove,
            value > min ? () => onChanged((value - step).clamp(min, max)) : null),
        Expanded(
          child: Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        _btn(Icons.add,
            value < max ? () => onChanged((value + step).clamp(min, max)) : null),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) => SizedBox(
        width: 28,
        height: 26,
        child: Material(
          color: onTap != null
              ? accentColor.withValues(alpha: 0.12)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Icon(icon,
                size: 13,
                color: onTap != null ? accentColor : Colors.grey[400]),
          ),
        ),
      );
}
