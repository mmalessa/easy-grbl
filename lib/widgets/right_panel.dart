import 'package:flutter/material.dart';
import '../machines/machine_mode.dart';
import '../models/svg_document.dart';
import '../services/grbl_service.dart';
import 'code_panel.dart';
import 'jog_panel.dart';
import 'position_panel.dart';
import 'run_panel.dart';
import 'panel_section_header.dart';

class RightPanel extends StatelessWidget {
  final SvgDocument? document;
  final GrblService service;
  final MachineType machineType;
  final VoidCallback? onToggleConnect;
  final VoidCallback? onStartJob;
  final VoidCallback? onExportGcode;

  const RightPanel({
    super.key,
    required this.document,
    required this.service,
    required this.machineType,
    this.onToggleConnect,
    this.onStartJob,
    this.onExportGcode,
  });

  @override
  Widget build(BuildContext context) {
    final profile = machineType.profile;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Machine ──────────────────────────────────────────────────
          PanelSectionHeader(
            title: 'Machine · ${profile.displayName}',
            icon: profile.icon,
          ),
          _MachinePanel(service: service, onToggleConnect: onToggleConnect),

          // ── Run Job ──────────────────────────────────────────────────
          const Divider(height: 1, thickness: 1),
          PanelSectionHeader(
            title: 'Run Job',
            icon: Icons.play_circle_outline,
          ),
          RunPanel(
            document: document,
            service: service,
            onStartJob: onStartJob,
            onExportGcode: onExportGcode,
          ),

          // ── Code ─────────────────────────────────────────────────────
          const Divider(height: 1, thickness: 1),
          PanelSectionHeader(
            title: 'Code',
            icon: Icons.terminal,
          ),
          Expanded(child: CodePanel(service: service)),

          // ── Position ─────────────────────────────────────────────────
          const Divider(height: 1, thickness: 1),
          PanelSectionHeader(
            title: 'Position',
            icon: Icons.my_location_outlined,
          ),
          PositionPanel(service: service),

          // ── Jog ──────────────────────────────────────────────────────
          const Divider(height: 1, thickness: 1),
          PanelSectionHeader(
            title: 'Jog',
            icon: Icons.gamepad_outlined,
          ),
          JogPanel(service: service),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _MachinePanel extends StatelessWidget {
  final GrblService service;
  final VoidCallback? onToggleConnect;

  const _MachinePanel({required this.service, this.onToggleConnect});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final connected = service.connected;
        final mock = service.isMock;

        final Color btnColor;
        final IconData btnIcon;
        final String btnLabel;
        final String statusLabel;

        if (!connected) {
          btnColor = cs.primary;
          btnIcon = Icons.link;
          btnLabel = 'Connect';
          statusLabel = 'Not connected';
        } else if (mock) {
          btnColor = const Color(0xFF8BC34A);
          btnIcon = Icons.link_off;
          btnLabel = 'Disconnect';
          statusLabel = 'Mock';
        } else {
          btnColor = const Color(0xFF2E7D32);
          btnIcon = Icons.link_off;
          btnLabel = 'Disconnect';
          statusLabel = 'Connected';
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? btnColor : cs.onSurfaceVariant.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: connected ? btnColor : cs.onSurfaceVariant,
                  fontWeight: connected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                child: FilledButton.icon(
                  onPressed: onToggleConnect,
                  style: FilledButton.styleFrom(
                    backgroundColor: connected
                        ? btnColor.withValues(alpha: 0.12)
                        : btnColor,
                    foregroundColor: connected ? btnColor : cs.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: connected
                          ? BorderSide(color: btnColor.withValues(alpha: 0.4))
                          : BorderSide.none,
                    ),
                  ),
                  icon: Icon(btnIcon, size: 13),
                  label: Text(btnLabel),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
