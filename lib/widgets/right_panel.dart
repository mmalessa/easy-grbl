import 'package:flutter/material.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/layer_settings.dart';
import '../services/grbl_mock_service.dart';
import 'layers_panel.dart';
import 'layer_settings_panel.dart';
import 'jog_panel.dart';
import 'run_panel.dart';

class RightPanel extends StatefulWidget {
  final SvgDocument? document;
  final SvgNode? selectedNode;
  final GrblMockService service;
  final void Function(SvgNode) onToggleEnabled;
  final void Function(SvgNode) onSelect;
  final void Function(SvgNode, LayerSettings) onSettingsChanged;

  const RightPanel({
    super.key,
    required this.document,
    required this.selectedNode,
    required this.service,
    required this.onToggleEnabled,
    required this.onSelect,
    required this.onSettingsChanged,
  });

  @override
  State<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<RightPanel> {
  bool _jogExpanded = false;

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
            child: widget.document == null
                ? const SizedBox(
                    height: 44,
                    child: Center(
                      child: Text('No file loaded',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  )
                : LayersPanel(
                    roots: widget.document!.roots,
                    onToggleEnabled: widget.onToggleEnabled,
                    onSelect: widget.onSelect,
                  ),
          ),

          // ── Rest: scrollable ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Layer Settings (when node selected)
                  if (widget.selectedNode != null) ...[
                    const Divider(height: 1, thickness: 1),
                    _SectionHeader(
                      title: 'Layer Settings',
                      icon: Icons.tune_outlined,
                      trailing: GestureDetector(
                        onTap: () => widget.onSelect(widget.selectedNode!),
                        child: const Icon(Icons.close, size: 14),
                      ),
                    ),
                    LayerSettingsPanel(
                      key: ValueKey(widget.selectedNode!.id),
                      node: widget.selectedNode!,
                      onChanged: (s) =>
                          widget.onSettingsChanged(widget.selectedNode!, s),
                    ),
                  ],

                  // Jog
                  const Divider(height: 1, thickness: 1),
                  _SectionHeader(
                    title: 'Jog',
                    icon: Icons.gamepad_outlined,
                    trailing: GestureDetector(
                      onTap: () =>
                          setState(() => _jogExpanded = !_jogExpanded),
                      child: Icon(
                        _jogExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  if (_jogExpanded) JogPanel(service: widget.service),

                  // Run Job
                  const Divider(height: 1, thickness: 1),
                  _SectionHeader(
                    title: 'Run Job',
                    icon: Icons.play_circle_outline,
                  ),
                  RunPanel(
                    document: widget.document,
                    service: widget.service,
                  ),
                ],
              ),
            ),
          ),
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
