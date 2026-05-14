import 'package:flutter/material.dart';
import '../models/svg_node.dart';
import '../models/svg_node_type.dart';
import '../models/operation_type.dart';

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
      return Center(
        child: Text('No elements', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
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
    final opColor = node.settings.operationType.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => widget.onSelect(node),
          child: Container(
            color: node.selected
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                : null,
            child: Row(
              children: [
                // Colored operation type bar on the left edge
                Container(
                  width: 3,
                  height: 26,
                  color: opColor,
                ),
                SizedBox(width: 4 + indent),
                // Expand/collapse arrow
                SizedBox(
                  width: 16,
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
                // Type icon (colored by operation for layers/groups)
                Icon(
                  _icon(node.type),
                  size: 13,
                  color: node.isGroup ? opColor : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                // Label
                Expanded(
                  child: Text(
                    node.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: node.enabled ? null : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: node.isGroup ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Eye toggle
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onToggleEnabled(node),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                    child: Icon(
                      node.enabled ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 13,
                      color: node.enabled ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
}
