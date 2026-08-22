import 'package:flutter/material.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/layer_settings.dart';
import '../models/machine_settings.dart';
import '../models/focus_test_config.dart';
import '../models/kerf_test_config.dart';
import '../models/spot_test_config.dart';
import '../models/test_session.dart';
import 'layers_panel.dart';
import 'layer_settings_panel.dart';
import 'panel_section_header.dart';
import 'focus_test_panel.dart';
import 'kerf_test_panel.dart';
import 'spot_test_panel.dart';

class LeftPanel extends StatefulWidget {
  final SvgDocument? document;
  final SvgNode? selectedNode;
  final MachineSettings machineSettings;
  final void Function(SvgNode) onToggleEnabled;
  final void Function(SvgNode) onSelect;
  final void Function(SvgNode, LayerSettings) onSettingsChanged;

  // At most one template test (Focus/Kerf/Spot) is active at a time.
  final TestSession testSession;
  final ValueChanged<FocusTestConfig> onFocusTestChanged;
  final ValueChanged<KerfTestConfig> onKerfTestChanged;
  final ValueChanged<SpotTestConfig> onSpotTestChanged;
  final VoidCallback onCloseTest;

  const LeftPanel({
    super.key,
    required this.document,
    required this.selectedNode,
    required this.machineSettings,
    required this.onToggleEnabled,
    required this.onSelect,
    required this.onSettingsChanged,
    required this.testSession,
    required this.onFocusTestChanged,
    required this.onKerfTestChanged,
    required this.onSpotTestChanged,
    required this.onCloseTest,
  });

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  bool _settingsCollapsed = false;
  double? _settingsHeight; // null = natural height
  final _settingsBoxKey = GlobalKey();

  @override
  void didUpdateWidget(LeftPanel old) {
    super.didUpdateWidget(old);
    if (old.selectedNode?.id != widget.selectedNode?.id) {
      _settingsCollapsed = false;
      _settingsHeight = null;
    }
  }

  void _onSettingsDrag(double delta) {
    final rb =
        _settingsBoxKey.currentContext?.findRenderObject() as RenderBox?;
    final current =
        (rb != null && rb.hasSize) ? rb.size.height : (_settingsHeight ?? 220.0);
    setState(() {
      _settingsHeight = (current - delta).clamp(80.0, 600.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSettings = widget.selectedNode != null;

    return Container(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (widget.testSession) {
            FocusTestSession(:final config) => Expanded(
                child: FocusTestPanel(
                  config: config,
                  onChanged: widget.onFocusTestChanged,
                  onClose: widget.onCloseTest,
                ),
              ),
            KerfTestSession(:final config) => Expanded(
                child: KerfTestPanel(
                  config: config,
                  onChanged: widget.onKerfTestChanged,
                  onClose: widget.onCloseTest,
                ),
              ),
            SpotTestSession(:final config) => Expanded(
                child: SpotTestPanel(
                  config: config,
                  spotSize: widget.machineSettings.laserSpotSize,
                  onChanged: widget.onSpotTestChanged,
                  onClose: widget.onCloseTest,
                ),
              ),
            NoTestSession() => Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Layers & Objects ────────────────────────────────
                    PanelSectionHeader(
                      title: 'Layers & Objects',
                      icon: Icons.layers_outlined,
                    ),
                    Expanded(
                      child: widget.document == null
                          ? Center(
                              child: Text(
                                'No file loaded',
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 12)))
                          : LayersPanel(
                              roots: widget.document!.roots,
                              onToggleEnabled: widget.onToggleEnabled,
                              onSelect: widget.onSelect,
                            ),
                    ),

                    // ── Layer Settings (shown when a node is selected) ──
                    if (hasSettings) ...[
                      if (!_settingsCollapsed)
                        _DragHandle(onDrag: _onSettingsDrag),
                      const Divider(height: 1, thickness: 1),
                      PanelSectionHeader(
                        title: 'Layer Settings',
                        icon: Icons.tune_outlined,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() =>
                                  _settingsCollapsed = !_settingsCollapsed),
                              child: Icon(
                                _settingsCollapsed
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 2),
                            GestureDetector(
                              onTap: () =>
                                  widget.onSelect(widget.selectedNode!),
                              child: const Icon(Icons.close, size: 14),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOut,
                        child: _settingsCollapsed
                            ? const SizedBox.shrink()
                            : ConstrainedBox(
                                key: _settingsBoxKey,
                                constraints: BoxConstraints(
                                  maxHeight: _settingsHeight ?? double.infinity,
                                ),
                                child: SingleChildScrollView(
                                  child: LayerSettingsPanel(
                                    key: ValueKey(widget.selectedNode!.id),
                                    node: widget.selectedNode!,
                                    machineSettings: widget.machineSettings,
                                    onChanged: (s) => widget.onSettingsChanged(
                                        widget.selectedNode!, s),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
          },
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DragHandle extends StatelessWidget {
  final ValueChanged<double> onDrag;

  const _DragHandle({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: SizedBox(
          height: 10,
          child: Center(
            child: Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
