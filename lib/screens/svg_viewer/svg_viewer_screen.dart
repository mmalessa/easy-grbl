import 'package:flutter/material.dart';
import '../../models/svg_document.dart';
import '../../models/svg_node.dart';
import '../../models/svg_node_type.dart';
import '../../services/svg_tree_parser.dart';
import '../../widgets/svg_document_painter.dart';

class SvgViewerScreen extends StatefulWidget {
  final String? svgContent;

  const SvgViewerScreen({super.key, this.svgContent});

  @override
  State<SvgViewerScreen> createState() => _SvgViewerScreenState();
}

class _SvgViewerScreenState extends State<SvgViewerScreen> {
  late SvgDocument document;

  @override
  void initState() {
    super.initState();
    final content = widget.svgContent ??
        '<svg viewBox="0 0 100 100"><path id="default" d="M 10 10 L 90 10 L 90 90 L 10 90 Z"/></svg>';
    document = SvgTreeParser.parse(content);
  }

  void _toggleEnabled(SvgNode node) {
    setState(() => node.enabled = !node.enabled);
  }

  void _selectNode(SvgNode node) {
    setState(() {
      _deselectAll(document.roots);
      node.selected = !node.selected;
    });
  }

  void _deselectAll(List<SvgNode> nodes) {
    for (final n in nodes) {
      n.selected = false;
      _deselectAll(n.children);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SVG Viewer')),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[100],
              child: CustomPaint(
                painter: SvgDocumentPainter(document: document),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          SizedBox(
            width: 280,
            child: _LayersPanel(
              roots: document.roots,
              onToggleEnabled: _toggleEnabled,
              onSelect: _selectNode,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _LayersPanel extends StatelessWidget {
  final List<SvgNode> roots;
  final void Function(SvgNode) onToggleEnabled;
  final void Function(SvgNode) onSelect;

  const _LayersPanel({
    required this.roots,
    required this.onToggleEnabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: Colors.grey[200],
          child: Row(children: [
            const Icon(Icons.layers_outlined, size: 15),
            const SizedBox(width: 6),
            Text('Layers & Objects',
                style: Theme.of(context).textTheme.labelMedium),
          ]),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: roots.isEmpty
              ? const Center(
                  child: Text('No elements', style: TextStyle(color: Colors.grey)),
                )
              : ListView(
                  children: roots
                      .map((n) => _NodeTile(
                            node: n,
                            depth: 0,
                            onToggleEnabled: onToggleEnabled,
                            onSelect: onSelect,
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _NodeTile extends StatefulWidget {
  final SvgNode node;
  final int depth;
  final void Function(SvgNode) onToggleEnabled;
  final void Function(SvgNode) onSelect;

  const _NodeTile({
    required this.node,
    required this.depth,
    required this.onToggleEnabled,
    required this.onSelect,
  });

  @override
  State<_NodeTile> createState() => _NodeTileState();
}

class _NodeTileState extends State<_NodeTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final indent = widget.depth * 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => widget.onSelect(node),
          child: Container(
            color: node.selected ? Colors.blue.withValues(alpha: 0.18) : null,
            padding: EdgeInsets.only(
                left: 4 + indent, right: 4, top: 2, bottom: 2),
            child: Row(
              children: [
                // Expand arrow (groups/layers only)
                SizedBox(
                  width: 18,
                  child: node.children.isNotEmpty
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              setState(() => _expanded = !_expanded),
                          child: Icon(
                            _expanded
                                ? Icons.arrow_drop_down
                                : Icons.arrow_right,
                            size: 16,
                          ),
                        )
                      : const SizedBox(),
                ),
                // Type icon
                Icon(_icon(node.type), size: 14, color: _iconColor(node.type)),
                const SizedBox(width: 5),
                // Label
                Expanded(
                  child: Text(
                    node.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: node.enabled ? null : Colors.grey[400],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Eye toggle
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onToggleEnabled(node),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      node.enabled
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 14,
                      color: node.enabled ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (node.children.isNotEmpty && _expanded)
          ...node.children.map((child) => _NodeTile(
                node: child,
                depth: widget.depth + 1,
                onToggleEnabled: widget.onToggleEnabled,
                onSelect: widget.onSelect,
              )),
      ],
    );
  }

  IconData _icon(SvgNodeType t) => switch (t) {
        SvgNodeType.layer => Icons.layers,
        SvgNodeType.group => Icons.folder_open_outlined,
        SvgNodeType.rect => Icons.crop_square_outlined,
        SvgNodeType.ellipse || SvgNodeType.circle => Icons.circle_outlined,
        SvgNodeType.line || SvgNodeType.polyline => Icons.show_chart,
        SvgNodeType.polygon => Icons.change_history_outlined,
        SvgNodeType.path => Icons.gesture,
        _ => Icons.article_outlined,
      };

  Color _iconColor(SvgNodeType t) => switch (t) {
        SvgNodeType.layer => Colors.blue[600]!,
        SvgNodeType.group => Colors.orange[600]!,
        _ => Colors.grey[600]!,
      };
}
