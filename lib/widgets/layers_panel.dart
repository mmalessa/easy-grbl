import 'package:flutter/material.dart';
import '../models/svg_node.dart';
import '../models/svg_node_type.dart';

class LayersPanel extends StatelessWidget {
  final List<SvgNode> roots;
  final void Function(SvgNode) onToggleEnabled;
  final void Function(SvgNode) onSelect;

  const LayersPanel({
    super.key,
    required this.roots,
    required this.onToggleEnabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (roots.isEmpty) {
      return const Center(
        child: Text('No elements', style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: roots
          .map((n) => NodeTile(
                node: n,
                depth: 0,
                onToggleEnabled: onToggleEnabled,
                onSelect: onSelect,
              ))
          .toList(),
    );
  }
}

class NodeTile extends StatefulWidget {
  final SvgNode node;
  final int depth;
  final void Function(SvgNode) onToggleEnabled;
  final void Function(SvgNode) onSelect;

  const NodeTile({
    super.key,
    required this.node,
    required this.depth,
    required this.onToggleEnabled,
    required this.onSelect,
  });

  @override
  State<NodeTile> createState() => _NodeTileState();
}

class _NodeTileState extends State<NodeTile> {
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
            padding: EdgeInsets.only(left: 4 + indent, right: 4, top: 2, bottom: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: node.children.isNotEmpty
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Icon(
                            _expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                            size: 16,
                          ),
                        )
                      : const SizedBox(),
                ),
                Icon(_icon(node.type), size: 14, color: _iconColor(node.type)),
                const SizedBox(width: 5),
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onToggleEnabled(node),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      node.enabled ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
          ...node.children.map((child) => NodeTile(
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
