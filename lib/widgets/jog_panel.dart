import 'package:flutter/material.dart';
import '../services/grbl_service.dart';

const _kSteps = [0.1, 1.0, 10.0];

class JogPanel extends StatelessWidget {
  final GrblService service;

  const JogPanel({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final enabled = service.isIdle;
        final step = service.stepMm;
        final stepZ = service.stepMmZ;
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // XY D-Pad + Z buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _JogPad(service: service, enabled: enabled, step: step),
                  const SizedBox(width: 55),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _JogBtn(
                        icon: Icons.keyboard_arrow_up,
                        enabled: enabled,
                        onTap: () => service.jog(0, 0, stepZ),
                      ),
                      const SizedBox(height: 4),
                      _JogBtn(
                        icon: Icons.keyboard_arrow_down,
                        enabled: enabled,
                        onTap: () => service.jog(0, 0, -stepZ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 42),
                ],
              ),
              const SizedBox(height: 16),

              // ── Step selectors (no labels) ─────────────────────
              _StepRow(step: step, stepZ: stepZ, service: service),
              const SizedBox(height: 10),

              // ── Commands ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _CmdBtn(
                      label: 'Go Home',
                      icon: Icons.home_outlined,
                      enabled: enabled,
                      onTap: service.homeAll,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _CmdBtn(
                      label: 'Set Home',
                      icon: Icons.gps_fixed,
                      enabled: enabled,
                      onTap: service.setOrigin,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _JogPad extends StatelessWidget {
  final GrblService service;
  final bool enabled;
  final double step;
  const _JogPad({required this.service, required this.enabled, required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 44),
            _JogBtn(
              icon: Icons.keyboard_arrow_up,
              enabled: enabled,
              onTap: () => service.jog(0, step, 0),
            ),
            const SizedBox(width: 44),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _JogBtn(
              icon: Icons.keyboard_arrow_left,
              enabled: enabled,
              onTap: () => service.jog(-step, 0, 0),
            ),
            const SizedBox(width: 4),
            _JogBtn(
              icon: Icons.home,
              enabled: enabled,
              onTap: service.homeAll,
            ),
            const SizedBox(width: 4),
            _JogBtn(
              icon: Icons.keyboard_arrow_right,
              enabled: enabled,
              onTap: () => service.jog(step, 0, 0),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 44),
            _JogBtn(
              icon: Icons.keyboard_arrow_down,
              enabled: enabled,
              onTap: () => service.jog(0, -step, 0),
            ),
            const SizedBox(width: 44),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _JogBtn extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final bool enabled;
  final VoidCallback onTap;

  const _JogBtn({
    this.icon,
    this.label,
    required this.enabled,
    required this.onTap,
  }) : assert(icon != null || label != null);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.grey[200] : Colors.grey[100],
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          width: 40,
          height: 36,
          child: Center(
            child: icon != null
                ? Icon(icon,
                    size: 20,
                    color: enabled ? Colors.grey[800] : Colors.grey[400])
                : Text(
                    label!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: enabled ? Colors.grey[800] : Colors.grey[400],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

String _fmt(double v) =>
    v >= 1 ? v.toInt().toString() : v.toStringAsFixed(v < 0.1 ? 2 : 1);

class _StepRow extends StatelessWidget {
  final double step;
  final double stepZ;
  final GrblService service;
  const _StepRow({required this.step, required this.stepZ, required this.service});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StepChip(value: step, onSelect: service.setStep),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StepChip(value: stepZ, onSelect: service.setStepZ),
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  final double value;
  final void Function(double) onSelect;

  const _StepChip({
    required this.value,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          ...(_kSteps.map((s) => Padding(
                padding: const EdgeInsets.only(right: 2),
                child: GestureDetector(
                  onTap: () => onSelect(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: value == s
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _fmt(s),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: value == s
                            ? Colors.white
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ))),
          Text('mm',
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CmdBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _CmdBtn({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.grey[200] : Colors.grey[100],
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 13,
                  color: enabled ? Colors.grey[700] : Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: enabled ? Colors.grey[800] : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
