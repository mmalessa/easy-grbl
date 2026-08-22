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
                      _JogIconButton(
                        icon: Icons.keyboard_arrow_up,
                        enabled: enabled,
                        onTap: () => service.jog(0, 0, stepZ),
                      ),
                      const SizedBox(height: 4),
                      _JogIconButton(
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
                    child: _JogCommandButton(
                      label: 'Go Home',
                      icon: Icons.home_outlined,
                      enabled: enabled,
                      onTap: service.homeAll,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _JogCommandButton(
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
            _JogIconButton(
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
            _JogIconButton(
              icon: Icons.keyboard_arrow_left,
              enabled: enabled,
              onTap: () => service.jog(-step, 0, 0),
            ),
            const SizedBox(width: 4),
            _JogIconButton(
              icon: Icons.home,
              enabled: enabled,
              onTap: service.homeAll,
            ),
            const SizedBox(width: 4),
            _JogIconButton(
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
            _JogIconButton(
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

/// Small square icon button used in the jog D-pad, Z buttons, and Home
/// button. Distinct in shape from [IconStepperButton] (fixed 40×36,
/// neutral surface background, no active-color tint) so kept as its own
/// widget rather than forced into that family — see refactor-todo.md P6.
class _JogIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _JogIconButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: enabled ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          width: 40,
          height: 36,
          child: Center(
            child: Icon(icon,
                size: 20,
                color: enabled ? cs.onSurface : cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
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
                          ? cs.primary
                          : cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _fmt(s),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: value == s
                            ? cs.onPrimary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ))),
          Text('mm',
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Full-width icon+label command button ("Go Home", "Set Home") — same
/// neutral-surface family as [_JogIconButton], different shape (icon +
/// text row instead of icon-only square), so named as a sibling rather
/// than merged with it.
class _JogCommandButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _JogCommandButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: enabled ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
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
                  color: enabled ? cs.onSurfaceVariant : cs.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: enabled ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
