import 'package:flutter/material.dart';
import '../services/grbl_service.dart';

class CodePanel extends StatefulWidget {
  final GrblService service;
  const CodePanel({super.key, required this.service});

  @override
  State<CodePanel> createState() => _CodePanelState();
}

class _CodePanelState extends State<CodePanel> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        _scrollToEnd();
        final log = widget.service.commLog;
        return Container(
          color: cs.surfaceContainerHighest,
          child: log.isEmpty
              ? Center(
                  child: Text(
                    'No activity',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: log.length,
                  itemBuilder: (_, i) {
                    final e = log[i];
                    final isComment = e.text.startsWith(';');
                    final Color color = isComment
                        ? cs.onSurfaceVariant
                        : e.rx
                            ? Colors.green
                            : Colors.cyan;
                    return Text(
                      e.rx ? '< ${e.text}' : '> ${e.text}',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: color,
                        height: 1.4,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
