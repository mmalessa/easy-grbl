import 'package:flutter/material.dart';
import '../services/grbl_service.dart';

class PositionPanel extends StatelessWidget {
  final GrblService service;
  const PositionPanel({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final connected = service.connected;
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Coord('X', service.x, dim: !connected, cs: cs),
                  _Coord('Y', service.y, dim: !connected, cs: cs),
                  _Coord('Z', service.z, dim: !connected, cs: cs),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                connected ? service.status.label : 'OFFLINE',
                style: TextStyle(
                  fontSize: 10,
                  color: connected ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Coord extends StatelessWidget {
  final String axis;
  final double value;
  final bool dim;
  final ColorScheme cs;
  const _Coord(this.axis, this.value, {this.dim = false, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Text(
            axis,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              fontSize: 12,
              color: dim ? cs.onSurfaceVariant.withValues(alpha: 0.6) : cs.onSurface,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
