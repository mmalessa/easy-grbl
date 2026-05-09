import 'package:flutter/material.dart';
import '../../models/svg_document.dart';
import '../../models/svg_node.dart';
import '../../services/svg_tree_parser.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/svg_preview_widget.dart';
import '../../widgets/right_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SvgDocument? _document;
  String _filename = '';

  void _onFileLoaded(String content, String filename) {
    setState(() {
      _document = SvgTreeParser.parse(content);
      _filename = filename;
    });
  }

  void _toggleEnabled(SvgNode node) {
    setState(() => node.enabled = !node.enabled);
  }

  void _selectNode(SvgNode node) {
    setState(() {
      _deselectAll(_document!.roots);
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
      appBar: MainAppBar(onFileLoaded: _onFileLoaded),
      body: Column(
        children: [
          if (_filename.isNotEmpty) _StatusBar(filename: _filename),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: SvgPreviewWidget(document: _document),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                SizedBox(
                  width: 280,
                  child: RightPanel(
                    document: _document,
                    onToggleEnabled: _toggleEnabled,
                    onSelect: _selectNode,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String filename;
  const _StatusBar({required this.filename});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      color: Colors.grey[200],
      child: Text(
        filename,
        style: const TextStyle(fontSize: 11, color: Colors.black54),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
