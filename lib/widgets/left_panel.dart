import 'package:flutter/material.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/layer_settings.dart';
import '../models/machine_settings.dart';
import '../models/focus_test_config.dart';
import '../models/kerf_test_config.dart';
import 'layers_panel.dart';
import 'layer_settings_panel.dart';
import 'panel_section_header.dart';
import 'focus_test_panel.dart';
import 'kerf_test_panel.dart';

class LeftPanel extends StatefulWidget {
  final SvgDocument? document;
  final SvgNode? selectedNode;
  final MachineSettings machineSettings;
  final void Function(SvgNode) onToggleEnabled;
  final void Function(SvgNode) onSelect;
  final void Function(SvgNode, LayerSettings) onSettingsChanged;

  // Focus Test
  final bool showFocusTest;
  final FocusTestConfig focusTestConfig;
  final ValueChanged<FocusTestConfig> onFocusTestChanged;
  final VoidCallback onFocusTestClose;

  // Kerf Test
  final bool showKerfTest;
  final KerfTestConfig kerfTestConfig;
  final ValueChanged<KerfTestConfig> onKerfTestChanged;
  final VoidCallback onKerfTestClose;

  const LeftPanel({
    super.key,
    required this.document,
    required this.selectedNode,
    required this.machineSettings,
    required this.onToggleEnabled,
    required this.onSelect,
    required this.onSettingsChanged,
    this.showFocusTest = false,
    required this.focusTestConfig,
    required this.onFocusTestChanged,
    required this.onFocusTestClose,
    this.showKerfTest = false,
    required this.kerfTestConfig,
    required this.onKerfTestChanged,
    required this.onKerfTestClose,
  });

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  double _settingsHeight = 240;

  @override
  Widget build(BuildContext context) {
    final hasSettings = widget.selectedNode != null;

    return Container(
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showFocusTest)
            Expanded(
              child: FocusTestPanel(
                config: widget.focusTestConfig,
                onChanged: widget.onFocusTestChanged,
                onClose: widget.onFocusTestClose,
              ),
            )
          else if (widget.showKerfTest)
            Expanded(
              child: KerfTestPanel(
                config: widget.kerfTestConfig,
                onChanged: widget.onKerfTestChanged,
                onClose: widget.onKerfTestClose,
              ),
            )
          else ...[
            // ── Layers & Objects ────────────────────────────────────────
            PanelSectionHeader(
              title: 'Layers & Objects',
              icon: Icons.layers_outlined,
            ),
            Expanded(
              child: widget.document == null
                  ? const Center(
                      child: Text(
                        'No file loaded',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    )
                  : LayersPanel(
                      roots: widget.document!.roots,
                      onToggleEnabled: widget.onToggleEnabled,
                      onSelect: widget.onSelect,
                    ),
            ),

            // ── Layer Settings (shown when a node is selected) ──────────
            if (hasSettings) ...[
              _DragHandle(
                onDrag: (delta) {
                  setState(() {
                    _settingsHeight =
                        (_settingsHeight - delta).clamp(150, 500);
                  });
                },
              ),
              const Divider(height: 1, thickness: 1),
              PanelSectionHeader(
                title: 'Layer Settings',
                icon: Icons.tune_outlined,
                trailing: GestureDetector(
                  onTap: () => widget.onSelect(widget.selectedNode!),
                  child: const Icon(Icons.close, size: 14),
                ),
              ),
              SizedBox(
                height: _settingsHeight,
                child: SingleChildScrollView(
                  child: LayerSettingsPanel(
                    key: ValueKey(widget.selectedNode!.id),
                    node: widget.selectedNode!,
                    machineSettings: widget.machineSettings,
                    onChanged: (s) =>
                        widget.onSettingsChanged(widget.selectedNode!, s),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DragHandle extends StatelessWidget {
  final void Function(double delta) onDrag;

  const _DragHandle({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
      child: Container(
        height: 10,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[350],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
