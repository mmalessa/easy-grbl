import 'package:flutter/material.dart';
import '../models/svg_document.dart';
import '../services/grbl_service.dart';
import 'jog_panel.dart';
import 'run_panel.dart';
import 'panel_section_header.dart';

class RightPanel extends StatelessWidget {
  final SvgDocument? document;
  final GrblService service;
  final VoidCallback? onExportGcode;
  final void Function(Rect svgBounds)? onFrame;

  const RightPanel({
    super.key,
    required this.document,
    required this.service,
    this.onExportGcode,
    this.onFrame,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),

          // ── Run Job ──────────────────────────────────────────────────
          const Divider(height: 1, thickness: 1),
          PanelSectionHeader(
            title: 'Run Job',
            icon: Icons.play_circle_outline,
          ),
          RunPanel(
            document: document,
            service: service,
            onExportGcode: onExportGcode,
            onFrame: onFrame,
          ),

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
