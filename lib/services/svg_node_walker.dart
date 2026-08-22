import '../models/svg_node.dart';
import '../models/layer_settings.dart';
import '../models/operation_type.dart';
import 'affine.dart';

/// This node's own operation type if set (i.e. not [OperationType.skip]),
/// otherwise the type inherited from the nearest ancestor that set one.
OperationType? resolveEffectiveOp(SvgNode node, OperationType? inheritedOp) {
  final own = node.settings.operationType;
  return own != OperationType.skip ? own : inheritedOp;
}

/// Settings to pass down to [node]'s children: its own settings once it
/// sets an operation type, otherwise whatever was inherited so far.
LayerSettings? inheritedSettingsFor(SvgNode node, LayerSettings? inherited) =>
    node.settings.operationType != OperationType.skip
        ? node.settings
        : inherited;

/// One step of SVG-node inheritance resolution: given [node] and its
/// parent's accumulated transform/visibility/inherited operation+settings,
/// returns this node's own resolved values. This is the actual duplicated
/// math shared by [walkSvgNodes] and by [SvgDocumentPainter] (which needs
/// its own traversal — canvas-stack transforms and selection-highlight
/// scope — but the same per-node resolution).
({
  SvgAffine transform,
  bool visible,
  OperationType? effectiveOp,
  LayerSettings effectiveSettings,
}) resolveNode(
  SvgNode node,
  SvgAffine parentTransform,
  bool parentVisible,
  OperationType? inheritedOp,
  LayerSettings? inheritedSettings,
) {
  final visible = parentVisible && node.enabled;
  final transform =
      parentTransform.multiply(SvgAffine.fromSvgString(node.transform));
  final effectiveOp = resolveEffectiveOp(node, inheritedOp);
  final effectiveSettings = node.settings.operationType != OperationType.skip
      ? node.settings
      : (inheritedSettings ?? node.settings);
  return (
    transform: transform,
    visible: visible,
    effectiveOp: effectiveOp,
    effectiveSettings: effectiveSettings,
  );
}

typedef SvgNodeVisitor = void Function(
  SvgNode node,
  SvgAffine transform,
  OperationType? effectiveOp,
  LayerSettings effectiveSettings,
);

/// Walks every *visible* node (this node and all ancestors enabled) in
/// [roots] depth-first, invoking [visit] with each one's resolved
/// transform and inherited operation/settings. Disabled nodes and their
/// entire subtrees are skipped — for a walk that must also see disabled
/// nodes (e.g. to render them dimmed), call [resolveNode] directly in a
/// custom traversal instead, as [SvgDocumentPainter] does.
void walkSvgNodes(List<SvgNode> roots, SvgNodeVisitor visit) {
  void walk(
    List<SvgNode> nodes,
    OperationType? inheritedOp,
    LayerSettings? inheritedSettings,
    SvgAffine parentTransform,
  ) {
    for (final node in nodes) {
      if (!node.enabled) continue;
      final r = resolveNode(
          node, parentTransform, true, inheritedOp, inheritedSettings);
      visit(node, r.transform, r.effectiveOp, r.effectiveSettings);
      walk(
        node.children,
        r.effectiveOp,
        inheritedSettingsFor(node, inheritedSettings),
        r.transform,
      );
    }
  }

  walk(roots, null, null, SvgAffine.identity);
}

/// True iff [pathData] is present and [effectiveOp] resolves to an active
/// (non-skip) operation — the "should this node actually be processed"
/// check shared by G-code generation, toolpath preview, and job counting.
bool isActiveOp(String? pathData, OperationType? effectiveOp) =>
    pathData != null && effectiveOp != null && effectiveOp != OperationType.skip;

/// Effective pass count for a node resolved to [effectiveOp]/[effectiveSettings]:
/// Fill always burns once (a scanline fill doesn't repeat like a cut/engrave
/// outline does), everything else uses the layer's configured pass count.
int effectivePassesFor(
        OperationType effectiveOp, LayerSettings effectiveSettings) =>
    effectiveOp == OperationType.fill ? 1 : effectiveSettings.passes;
