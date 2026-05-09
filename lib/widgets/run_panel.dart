import 'package:flutter/material.dart';
import '../models/svg_document.dart';
import '../services/grbl_mock_service.dart';

class RunPanel extends StatelessWidget {
  final SvgDocument? document;
  final GrblMockService service;

  const RunPanel({super.key, required this.document, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (document == null) {
          return _hint('Load an SVG file to run a job.');
        }
        if (!service.connected) {
          return _hint('Connect to machine to run a job.');
        }
        if (service.isJobRunning) {
          return _running(context);
        }
        return _idle(context);
      },
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Text(text,
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
      );

  Widget _idle(BuildContext context) {
    final roots = document!.roots;
    final (:paths, :passes) = service.countJobSteps(roots);
    final canRun = paths > 0;
    final estimateSec = (passes * 5).clamp(1, 9999);
    final estLabel = estimateSec < 60
        ? '~${estimateSec}s'
        : '~${estimateSec ~/ 60}m ${estimateSec % 60}s';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary row
          Row(
            children: [
              Icon(Icons.layers_outlined, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 5),
              Text(
                canRun
                    ? '$paths path${paths == 1 ? '' : 's'}  •  $passes pass${passes == 1 ? '' : 'es'}  •  $estLabel'
                    : 'No active paths — set operation types on layers',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Start button
          FilledButton.icon(
            onPressed: canRun ? () => service.startJob(roots) : null,
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
        ],
      ),
    );
  }

  Widget _running(BuildContext context) {
    final progress = service.jobProgress;
    final label = service.jobCurrentLabel;
    final paused = service.isJobPaused;
    final pct = (progress * 100).round();
    final isComplete = label == 'Complete';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress bar + percentage
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete
                          ? const Color(0xFF388E3C)
                          : paused
                              ? Colors.orange.shade400
                              : const Color(0xFFFF9800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text(
                  isComplete ? '✓' : '$pct%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isComplete
                        ? const Color(0xFF388E3C)
                        : Colors.grey[700],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Current step label
          Text(
            paused ? 'Paused — $label' : label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: paused ? FontStyle.italic : FontStyle.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (!isComplete) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CtrlBtn(
                    label: paused ? 'Resume' : 'Pause',
                    icon: paused ? Icons.play_arrow : Icons.pause,
                    onTap: paused ? service.resumeJob : service.pauseJob,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CtrlBtn(
                    label: 'Stop',
                    icon: Icons.stop,
                    onTap: service.stopJob,
                    danger: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CtrlBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _CtrlBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red.shade700 : Colors.grey[800]!;
    return Material(
      color: danger ? Colors.red.shade50 : Colors.grey[200],
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
