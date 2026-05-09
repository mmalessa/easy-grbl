import 'svg_node_type.dart';
import 'layer_settings.dart';

class SvgNode {
  final String id;
  final String label;
  final SvgNodeType type;
  final List<SvgNode> children;
  final String? pathData;
  final String? transform;
  bool enabled;
  bool selected;
  LayerSettings settings;

  SvgNode({
    required this.id,
    required this.label,
    required this.type,
    List<SvgNode>? children,
    this.pathData,
    this.transform,
    this.enabled = true,
    this.selected = false,
    LayerSettings? settings,
  })  : children = children ?? [],
        settings = settings ?? LayerSettings();

  bool get isLeaf => children.isEmpty;
  bool get isLayer => type == SvgNodeType.layer;
  bool get isGroup => type == SvgNodeType.group || type == SvgNodeType.layer;
}
