import 'package:flutter/material.dart';
import '../models/svg_document.dart';
import '../services/grbl_service.dart';

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
        if (document == null) {
          return _hint('Load an SVG file to run a job.');
        }
        if (service.isJobRunning) return _running(context);
        return _idle(context);
      },
    );
  }

  static Widget _iconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
    bool enabled = true,
  }) {
    final widget = Material(
      color: enabled ? Colors.grey[200] : Colors.grey[100],
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          width: 38,
          height: 40,
          child: Icon(icon,
              size: 18, color: enabled ? color : Colors.grey[400]),
        ),
      ),
    );
    return tooltip != null
        ? Tooltip(message: tooltip, child: widget)
        : widget;
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Text(text,
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
      );

  Widget _idle(BuildContext context) {
    final roots = document!.roots;
    final (:paths, :passes) = service.countJobSteps(roots);
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
              Icon(Icons.layers_outlined, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  paths > 0
                      ? '$paths path${paths == 1 ? '' : 's'}  •  $passes pass${passes == 1 ? '' : 'es'}  •  $estLabel'
                      : 'No active paths — set operation types on layers',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF388E3C),
                    disabledBackgroundColor: Colors.grey[200],
                    disabledForegroundColor: Colors.grey[500],
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (onExportGcode != null) ...[
                const SizedBox(width: 6),
                _iconBtn(
                  icon: Icons.code,
                  color: const Color(0xFF1565C0),
                  tooltip: 'Export G-code',
                  onTap: onExportGcode!,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _running(BuildContext context) {
    final progress = service.jobProgress;
    final label = service.jobCurrentLabel;
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
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF9800)),
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
                      color: Colors.grey[700]),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: service.stopJob,
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('STOP'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
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

