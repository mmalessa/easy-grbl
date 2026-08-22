import 'package:flutter/material.dart';
import '../models/svg_document.dart';
import '../services/grbl_service.dart';
import '../services/job_step_counter.dart';

class RunPanel extends StatelessWidget {
  final SvgDocument? document;
  final GrblService service;
  final VoidCallback? onStartJob;
  final VoidCallback? onExportGcode;

  const RunPanel({
    super.key,
    required this.document,
    required this.service,
    this.onStartJob,
    this.onExportGcode,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        if (document == null) {
          return _hint('Load an SVG file to run a job.', cs);
        }
        if (!service.connected) {
          return _hint('Connect to machine to run a job.', cs);
        }
        if (service.isJobRunning) return _running(context, cs);
        return _idle(context, cs);
      },
    );
  }

  static Widget _iconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required ColorScheme cs,
    String? tooltip,
    bool enabled = true,
  }) {
    final widget = Material(
      color: enabled ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          width: 38,
          height: 40,
          child: Icon(icon,
              size: 18, color: enabled ? color : cs.onSurfaceVariant),
        ),
      ),
    );
    return tooltip != null
        ? Tooltip(message: tooltip, child: widget)
        : widget;
  }

  Widget _hint(String text, ColorScheme cs) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Text(text,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
      );

  Widget _idle(BuildContext context, ColorScheme cs) {
    final roots = document!.roots;
    final (:paths, :passes) = countJobSteps(roots);
    final canRun = paths > 0 && service.isIdle;

    final estimateSec = (passes * 5).clamp(1, 9999);
    final estLabel = estimateSec < 60
        ? '~${estimateSec}s'
        : '~${estimateSec ~/ 60}m ${estimateSec % 60}s';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.layers_outlined, size: 12, color: cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  paths > 0
                      ? '$paths path${paths == 1 ? '' : 's'}  •  $passes pass${passes == 1 ? '' : 'es'}  •  $estLabel'
                      : 'No active paths — set operation types on layers',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: canRun
                      ? (onStartJob ?? () => service.startJob(document!))
                      : null,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Start Job'),
                ),
              ),
              if (onExportGcode != null) ...[
                const SizedBox(width: 6),
                _iconBtn(
                  icon: Icons.code,
                  color: cs.primary,
                  tooltip: 'Export G-code',
                  onTap: onExportGcode!,
                  cs: cs,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _running(BuildContext context, ColorScheme cs) {
    final progress = service.jobProgress;
    final pct = (progress * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerLow,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        cs.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text(
                  '$pct%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: service.stopJob,
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('STOP'),
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

