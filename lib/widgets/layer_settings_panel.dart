import 'package:flutter/material.dart';
import '../models/svg_node.dart';
import '../models/svg_node_type.dart';
import '../models/layer_settings.dart';
import '../machines/gcode/gcode_strategy.dart';
import '../machines/machine_settings.dart';
import '../machines/machine_mode.dart';
import '../models/operation_type.dart';
import 'icon_stepper_button.dart';

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
  late double _speed;
  late int _passes;
  late FillDirection _fillDirection;
  late double _linesPerMm;
  late bool _fillOutline;
  late CutSide _cutSide;
  late TextEditingController _cutDepthCtrl;

  @override
  void initState() {
    super.initState();
    _cutDepthCtrl = TextEditingController();
    _load();
  }

  @override
  void didUpdateWidget(LayerSettingsPanel old) {
    super.didUpdateWidget(old);
    if (old.node.id != widget.node.id) setState(_load);
  }

  @override
  void dispose() {
    _cutDepthCtrl.dispose();
    super.dispose();
  }

  void _load() {
    final s = widget.node.settings;
    _opType = s.operationType;
    _power = s.powerPercent.toDouble();
    _speed = s.speedMmS;
    _passes = s.passes;
    _fillDirection = s.fillDirection;
    _linesPerMm = s.linesPerMm;
    _fillOutline = s.fillOutline;
    _cutSide = s.cutSide;
    _cutDepthCtrl.text = s.cutDepthMm.toStringAsFixed(2);
  }

  double get _cutDepthMm {
    final v = double.tryParse(_cutDepthCtrl.text.replaceAll(',', '.'));
    return (v != null && v > 0) ? v : 1.0;
  }

  void _emit() => widget.onChanged(LayerSettings(
        operationType: _opType,
        powerPercent: _power.round(),
        speedMmS: _speed,
        passes: _passes,
        fillDirection: _fillDirection,
        linesPerMm: _linesPerMm,
        fillOutline: _fillOutline,
        cutSide: _cutSide,
        cutDepthMm: _cutDepthMm,
      ));

  double get _effectiveDiam => GcodeStrategy.of(widget.machineSettings)
      .effectiveDiameterAt(_cutDepthMm);

  double get _autoLinesPerMm {
    final spot = widget.machineSettings.laser.laserSpotSize;
    return spot > 0 ? 1.0 / spot : 10.0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _opType == OperationType.skip
        ? Colors.grey
        : _opType.color;
    final isFill = _opType == OperationType.fill;
    final isCut = _opType == OperationType.cut;

    return Container(
      color: cs.surface,
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
                final profile = ms.machineType.profile;
                if (v == OperationType.engrave) {
                  _power = ms.laser.engravePower.toDouble();
                  _speed = profile.defaultSpeedMmS(v, ms);
                } else if (v == OperationType.cut) {
                  _power = ms.laser.cutPower.toDouble();
                  _speed = profile.defaultSpeedMmS(v, ms);
                } else if (v == OperationType.fill) {
                  _power = ms.laser.fillPower.toDouble();
                  _speed = profile.defaultSpeedMmS(v, ms);
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
              inactiveTrackColor: cs.surfaceContainerHighest,
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
          _label('Speed (mm/s)'),
          const SizedBox(height: 4),
          _SpeedCounter(
            value: _speed,
            color: color,
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
            Divider(height: 16, thickness: 1, color: cs.outlineVariant),
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
                  color: cs.onSurfaceVariant,
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
            const SizedBox(height: 8),
            _OutlineCheckbox(
              value: _fillOutline,
              color: color,
              spotSize: widget.machineSettings.laser.laserSpotSize,
              onChanged: (v) {
                setState(() => _fillOutline = v);
                _emit();
              },
            ),
          ],

          // Cut-specific settings
          if (isCut) ...[
            Divider(height: 16, thickness: 1, color: cs.outlineVariant),
            _label('Cut side'),
            const SizedBox(height: 4),
            _CutSidePicker(
              value: _cutSide,
              color: color,
              onChanged: (v) {
                setState(() => _cutSide = v);
                _emit();
              },
            ),
            if (widget.machineSettings.machineType.profile.showsCutDepth) ...[
              const SizedBox(height: 10),
              _label('Cut depth (mm)'),
              const SizedBox(height: 4),
              _DepthCounter(
                controller: _cutDepthCtrl,
                color: color,
                onChanged: () {
                  setState(() {});
                  _emit();
                },
              ),
            ],
            if (_cutSide != CutSide.line) ...[
              const SizedBox(height: 6),
              Text(
                'Effective Ø ${_effectiveDiam.toStringAsFixed(3)} mm '
                '→ offset ${(_effectiveDiam / 2).toStringAsFixed(3)} mm (${_cutSide.label})',
                style: TextStyle(
                  fontSize: 9,
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
            fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.5),
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
    final cs = Theme.of(context).colorScheme;
    const ops = [OperationType.engrave, OperationType.cut, OperationType.fill];
    return Row(
      children: [
        GestureDetector(
          onTap: () => onChanged(OperationType.skip),
          child: Container(
            width: 26,
            margin: const EdgeInsets.only(right: 3),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              border: Border.all(color: cs.outlineVariant, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.close, size: 10, color: cs.onSurfaceVariant),
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
                        : cs.surfaceContainerLowest,
                    border: Border.all(
                      color: t == value ? t.color : cs.outlineVariant,
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
                      color: t == value ? t.color : cs.onSurfaceVariant,
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
    final cs = Theme.of(context).colorScheme;
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
                color: sel ? color.withValues(alpha: 0.15) : cs.surfaceContainerLowest,
                border: Border.all(
                  color: sel ? color : cs.outlineVariant,
                  width: sel ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 12,
                      color: sel ? color : cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          sel ? FontWeight.w700 : FontWeight.normal,
                      color: sel ? color : cs.onSurfaceVariant,
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

class _CutSidePicker extends StatelessWidget {
  final CutSide value;
  final Color color;
  final void Function(CutSide) onChanged;

  const _CutSidePicker({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: CutSide.values.map((side) {
        final sel = side == value;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(side),
            child: Container(
              margin: const EdgeInsets.only(right: 3),
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: sel ? color.withValues(alpha: 0.15) : cs.surfaceContainerLowest,
                border: Border.all(
                  color: sel ? color : cs.outlineVariant,
                  width: sel ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                side.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                  color: sel ? color : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------

class _DepthCounter extends StatelessWidget {
  final TextEditingController controller;
  final Color color;
  final VoidCallback onChanged;

  const _DepthCounter({
    required this.controller,
    required this.color,
    required this.onChanged,
  });

  static const double step = 0.1;
  static const double min = 0.01;
  static const double max = 50.0;

  double? get _parsed => double.tryParse(controller.text.replaceAll(',', '.'));
  bool get _isValid {
    final v = _parsed;
    return v != null && v > 0;
  }

  void _nudge(double delta) {
    final v = (_parsed ?? min) + delta;
    controller.text = v.clamp(min, max).toStringAsFixed(2);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final valid = _isValid;
    return Row(
      children: [
        IconStepperButton(
            icon: Icons.remove, onTap: () => _nudge(-step), color: color),
        Expanded(
          child: SizedBox(
            height: 26,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valid ? cs.onSurface : cs.error,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                filled: true,
                fillColor: cs.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: valid ? cs.outline : cs.error),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: valid ? cs.outline : cs.error),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: valid ? color : cs.error),
                ),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ),
        IconStepperButton(
            icon: Icons.add, onTap: () => _nudge(step), color: color),
      ],
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
    final cs = Theme.of(context).colorScheme;
    final step = _step(value);
    return Row(
      children: [
        IconStepperButton(
            icon: Icons.remove,
            onTap: value > 0.5
                ? () => onChanged((value - step).clamp(0.5, 100.0))
                : null,
            color: color),
        Expanded(
          child: Text(
            value == value.roundToDouble()
                ? value.toInt().toString()
                : value.toStringAsFixed(1),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        IconStepperButton(
            icon: Icons.add,
            onTap: value < 100
                ? () => onChanged((value + step).clamp(0.5, 100.0))
                : null,
            color: color),
        const SizedBox(width: 6),
        SizedBox(
          width: 36,
          height: 26,
          child: Tooltip(
            message: 'Reset to auto (${autoValue.toStringAsFixed(1)})',
            child: Material(
              color: value == autoValue
                  ? color.withValues(alpha: 0.12)
                  : cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                onTap: onReset,
                borderRadius: BorderRadius.circular(4),
                child: Icon(
                  Icons.autorenew,
                  size: 13,
                  color: value == autoValue ? color : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _SpeedCounter extends StatelessWidget {
  final double value;
  final Color color;
  final void Function(double) onChanged;

  const _SpeedCounter({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  static const double _step = 1.0;
  static const double _min = 0.1;
  static const double _max = 500.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconStepperButton(
            icon: Icons.remove,
            onTap: value > _min
                ? () => onChanged((value - _step).clamp(_min, _max))
                : null,
            color: color),
        Expanded(
          child: Text(
            value.toStringAsFixed(1),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        IconStepperButton(
            icon: Icons.add,
            onTap: value < _max
                ? () => onChanged((value + _step).clamp(_min, _max))
                : null,
            color: color),
      ],
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
        IconStepperButton(
            icon: Icons.remove,
            onTap: value > min
                ? () => onChanged((value - step).clamp(min, max))
                : null,
            color: accentColor),
        Expanded(
          child: Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        IconStepperButton(
            icon: Icons.add,
            onTap: value < max
                ? () => onChanged((value + step).clamp(min, max))
                : null,
            color: accentColor),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _OutlineCheckbox extends StatelessWidget {
  final bool value;
  final Color color;
  final double spotSize;
  final void Function(bool) onChanged;

  const _OutlineCheckbox({
    required this.value,
    required this.color,
    required this.spotSize,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inset = spotSize / 2;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: Checkbox(
                value: value,
                activeColor: color,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Outline',
                    style: TextStyle(
                      fontSize: 11,
                      color: value ? color : cs.onSurface,
                      fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (value)
                    Text(
                      'fill inset by ${inset.toStringAsFixed(3)} mm (½ spot size)',
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
