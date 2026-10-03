import '../models/svg_node.dart';
import '../geometry/svg_node_walker.dart';

/// Counts enabled non-skip paths/passes for the UI job summary. Pure domain
/// logic over the SVG node tree — doesn't depend on any machine/service
/// state, so it lives as a free function rather than on [GrblService].
({int paths, int passes}) countJobSteps(List<SvgNode> roots) {
  var paths = 0;
  var passes = 0;
  walkSvgNodes(roots, (node, transform, effectiveOp, effectiveSettings) {
    if (isNegativeFillGroup(node)) {
      // One fill of the whole area outside the group's objects.
      paths++;
      passes++;
    } else if (isActiveOp(node.pathData, effectiveOp) &&
        !isCoveredByNegativeFill(node, effectiveOp, effectiveSettings)) {
      paths++;
      passes += effectivePassesFor(effectiveOp!, effectiveSettings);
    }
  });
  return (paths: paths, passes: passes);
}
