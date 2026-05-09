import 'package:flutter/material.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/layer_settings.dart';
import 'layers_panel.dart';
import 'layer_settings_panel.dart';
import 'panel_section_header.dart';

class LeftPanel extends StatelessWidget {
  final SvgDocument? document;
  final SvgNode? selectedNode;
  final void Function(SvgNode) onToggleEnabled;
  final void Function(SvgNode) onSelect;
  final void Function(SvgNode, LayerSettings) onSettingsChanged;

  const LeftPanel({
    super.key,
    required this.document,
    required this.selectedNode,
    required this.onToggleEnabled,
    required this.onSelect,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Layers & Objects ──────────────────────────────────────────
          PanelSectionHeader(
            title: 'Layers & Objects',
            icon: Icons.layers_outlined,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: document == null
                ? const SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        'No file loaded',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  )
                : LayersPanel(
                    roots: document!.roots,
                    onToggleEnabled: onToggleEnabled,
                    onSelect: onSelect,
                  ),
          ),

          // ── Layer Settings (shown when a node is selected) ────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (selectedNode != null) ...[
                    const Divider(height: 1, thickness: 1),
                    PanelSectionHeader(
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
        ],
      ),
    );
  }
}
