import 'package:flutter/material.dart';
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
  final VoidCallback? onStartJob;
  final VoidCallback? onExportGcode;

  const RightPanel({
    super.key,
    required this.document,
    required this.service,
    this.onStartJob,
    this.onExportGcode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Run Job ──────────────────────────────────────────────────
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
