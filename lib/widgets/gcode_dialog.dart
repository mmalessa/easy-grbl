import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';

Future<void> showGcodeDialog(
    BuildContext context, String gcode, String sourceFilename) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _GcodeDialog(gcode: gcode, sourceFilename: sourceFilename),
  );
}

class _GcodeDialog extends StatefulWidget {
  final String gcode;
  final String sourceFilename;
  const _GcodeDialog({required this.gcode, required this.sourceFilename});

  @override
  State<_GcodeDialog> createState() => _GcodeDialogState();
}

class _GcodeDialogState extends State<_GcodeDialog> {
  bool _copied = false;

  String get _suggestedName =>
      '${widget.sourceFilename.replaceAll(RegExp(r'\.[^.]+$'), '')}.nc';

  int get _lineCount => '\n'.allMatches(widget.gcode).length + 1;

  String get _sizeLabel {
    final bytes = widget.gcode.length;
    return bytes < 1024
        ? '${bytes}B'
        : '${(bytes / 1024).toStringAsFixed(1)}KB';
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.gcode));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  Future<void> _save() async {
    final location = await getSaveLocation(
      suggestedName: _suggestedName,
      acceptedTypeGroups: [
        const XTypeGroup(label: 'G-code', extensions: ['nc', 'gcode', 'cnc']),
        const XTypeGroup(label: 'All files'),
      ],
    );
    if (location == null) return;
    await File(location.path).writeAsString(widget.gcode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${location.path}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
            maxWidth: 760, maxHeight: 580, minWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(
              filename: _suggestedName,
              lines: _lineCount,
              size: _sizeLabel,
              onClose: () => Navigator.of(context).pop(),
              cs: cs,
            ),
            Divider(height: 1, color: cs.outlineVariant),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  widget.gcode,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: cs.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ),

            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                    icon: _copied ? Icons.check : Icons.copy_outlined,
                    label: _copied ? 'Copied!' : 'Copy',
                    onTap: _copy,
                    accent: _copied,
                    cs: cs,
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    icon: Icons.save_alt_outlined,
                    label: 'Save as…',
                    onTap: _save,
                    cs: cs,
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  final String filename;
  final int lines;
  final String size;
  final VoidCallback onClose;
  final ColorScheme cs;

  const _TitleBar({
    required this.filename,
    required this.lines,
    required this.size,
    required this.onClose,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Icon(Icons.code, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            filename,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$lines lines  •  $size',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: cs.onSurfaceVariant,
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;
  final ColorScheme cs;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ? Colors.green : cs.primary;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: TextButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
