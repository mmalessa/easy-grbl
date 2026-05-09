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
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        _scrollToEnd();
        final log = widget.service.commLog;
        return Container(
          color: const Color(0xFF1A1A1A),
          child: log.isEmpty
              ? Center(
                  child: Text(
                    'No activity',
                    style: TextStyle(color: Colors.grey[700], fontSize: 11),
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
                        ? Colors.grey[600]!
                        : e.rx
                            ? const Color(0xFF81C784)
                            : const Color(0xFF80DEEA);
                    return Text(
                      e.rx ? '< ${e.text}' : '> ${e.text}',
                      style: TextStyle(
                        fontSize: 10,
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
