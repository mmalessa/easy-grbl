import 'dart:ui' show Rect;
import 'package:flutter/material.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/layer_settings.dart';
import '../services/grbl_service.dart';
import 'layers_panel.dart';
import 'layer_settings_panel.dart';
import 'jog_panel.dart';
import 'run_panel.dart';

class RightPanel extends StatelessWidget {
  final SvgDocument? document;
  final SvgNode? selectedNode;
  final GrblService service;
  final void Function(SvgNode) onToggleEnabled;
  final void Function(SvgNode) onSelect;
  final void Function(SvgNode, LayerSettings) onSettingsChanged;
  final VoidCallback? onExportGcode;
  final void Function(Rect svgBounds)? onFrame;

  const RightPanel({
    super.key,
    required this.document,
    required this.selectedNode,
    required this.service,
    required this.onToggleEnabled,
    required this.onSelect,
    required this.onSettingsChanged,
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
          // ── Layers & Objects (fixed max-height, scrolls internally) ──
          _SectionHeader(title: 'Layers & Objects', icon: Icons.layers_outlined),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: document == null
                ? const SizedBox(
                    height: 44,
                    child: Center(
                      child: Text('No file loaded',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  )
                : LayersPanel(
                    roots: document!.roots,
                    onToggleEnabled: onToggleEnabled,
                    onSelect: onSelect,
                  ),
          ),

          // ── Layer Settings (scrollable, shown when a node is selected) ──
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (selectedNode != null) ...[
                    const Divider(height: 1, thickness: 1),
                    _SectionHeader(
                      title: 'Layer Settings',
                      icon: Icons.tune_outlined,
                      trailing: GestureDetector(
                        onTap: () => onSelect(selectedNode!),
                        child: const Icon(Icons.close, size: 14),
                      ),
                    ),
                    LayerSettingsPanel(
                      key: ValueKey(selectedNode!.id),
                      node: selectedNode!,
                      onChanged: (s) => onSettingsChanged(selectedNode!, s),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Run Job (always visible) ──────────────────────────────────
          const Divider(height: 1, thickness: 1),
          _SectionHeader(
            title: 'Run Job',
            icon: Icons.play_circle_outline,
          ),
          RunPanel(
            document: document,
            service: service,
            onExportGcode: onExportGcode,
            onFrame: onFrame,
          ),

          // ── Jog (always visible at bottom) ────────────────────────────
          const Divider(height: 1, thickness: 1),
          _SectionHeader(
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: Colors.grey[200],
      child: Row(children: [
        Icon(icon, size: 13, color: Colors.grey[700]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
