import 'package:flutter/material.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import 'layers_panel.dart';

class RightPanel extends StatefulWidget {
  final SvgDocument? document;
  final void Function(SvgNode) onToggleEnabled;
  final void Function(SvgNode) onSelect;

  const RightPanel({
    super.key,
    required this.document,
    required this.onToggleEnabled,
    required this.onSelect,
  });

  @override
  State<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<RightPanel> {
  bool _layersExpanded = true;
  bool _jogExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          _PanelSection(
            title: 'Layers & Objects',
            icon: Icons.layers_outlined,
            expanded: _layersExpanded,
            onToggle: () => setState(() => _layersExpanded = !_layersExpanded),
            child: widget.document == null
                ? const SizedBox(
                    height: 60,
                    child: Center(
                      child: Text('No file loaded',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  )
                : SizedBox(
                    height: 300,
                    child: LayersPanel(
                      roots: widget.document!.roots,
                      onToggleEnabled: widget.onToggleEnabled,
                      onSelect: widget.onSelect,
                    ),
                  ),
          ),
          const Divider(height: 1, thickness: 1),
          _PanelSection(
            title: 'Jog',
            icon: Icons.gamepad_outlined,
            expanded: _jogExpanded,
            onToggle: () => setState(() => _jogExpanded = !_jogExpanded),
            child: const SizedBox(
              height: 60,
              child: Center(
                child: Text('Coming in Phase 5',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          const Spacer(),
        ],
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _PanelSection({
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.grey[200],
            child: Row(children: [
              Icon(icon, size: 14, color: Colors.grey[700]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Icon(expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: Colors.grey[600]),
            ]),
          ),
        ),
        if (expanded) child,
      ],
    );
  }
}
