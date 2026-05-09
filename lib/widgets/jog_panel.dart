import 'package:flutter/material.dart';
import '../services/grbl_service.dart';

const _kSteps = [0.01, 0.1, 1.0, 10.0];

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
              // ── Position display ──────────────────────────────
              _PositionDisplay(service: service),
              const SizedBox(height: 10),

              // ── XY jog pad ────────────────────────────────────
              _JogPad(service: service, enabled: enabled, step: step),
              const SizedBox(height: 6),

              // ── Z axis + Z step ───────────────────────────────
              Row(
                children: [
                  _JogBtn(
                    label: 'Z+',
                    enabled: enabled,
                    onTap: () => service.jog(0, 0, stepZ),
                  ),
                  const SizedBox(width: 4),
                  _JogBtn(
                    label: 'Z−',
                    enabled: enabled,
                    onTap: () => service.jog(0, 0, -stepZ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StepSelector(
                      label: 'Z',
                      current: stepZ,
                      onSelect: service.setStepZ,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── XY step selector ──────────────────────────────
              _StepSelector(
                label: 'XY',
                current: step,
                onSelect: service.setStep,
              ),
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

class _PositionDisplay extends StatelessWidget {
  final GrblService service;
  const _PositionDisplay({required this.service});

  @override
  Widget build(BuildContext context) {
    final connected = service.connected;
    final rgb = service.status.rgb;
    final statusColor = connected
        ? Color.fromRGBO(rgb.r, rgb.g, rgb.b, 1)
        : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Coord(label: 'X', value: service.x, dim: !connected),
              const SizedBox(width: 6),
              _Coord(label: 'Y', value: service.y, dim: !connected),
              const SizedBox(width: 6),
              _Coord(label: 'Z', value: service.z, dim: !connected),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  border: Border.all(color: statusColor, width: 0.8),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  connected ? service.status.label : 'OFFLINE',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Coord extends StatelessWidget {
  final String label;
  final double value;
  final bool dim;
  const _Coord({required this.label, required this.value, this.dim = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(width: 3),
          Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              color: dim ? Colors.grey[700] : Colors.white,
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
              // Up = +Y in machine coords (origin at bottom-left)
              onTap: () => service.jog(0, step, 0),
            ),
            const SizedBox(width: 44),
          ],
        ),
        const SizedBox(height: 4),
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
              tooltip: 'Go Home',
            ),
            const SizedBox(width: 4),
            _JogBtn(
              icon: Icons.keyboard_arrow_right,
              enabled: enabled,
              onTap: () => service.jog(step, 0, 0),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 44),
            _JogBtn(
              icon: Icons.keyboard_arrow_down,
              enabled: enabled,
              // Down = -Y in machine coords
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
  final String? tooltip;

  const _JogBtn({
    this.icon,
    this.label,
    required this.enabled,
    required this.onTap,
    this.tooltip,
  }) : assert(icon != null || label != null);

  @override
  Widget build(BuildContext context) {
    final btn = Material(
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

    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

// ---------------------------------------------------------------------------

class _StepSelector extends StatelessWidget {
  final String label;
  final double current;
  final void Function(double) onSelect;

  const _StepSelector({
    required this.label,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(width: 5),
        ...(_kSteps.map((s) => Padding(
              padding: const EdgeInsets.only(right: 3),
              child: GestureDetector(
                onTap: () => onSelect(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: current == s
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s < 1 ? s.toString() : s.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: current == s ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ))),
        Text('mm', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
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
