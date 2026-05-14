import 'package:flutter/material.dart';
import '../services/grbl_serial_service.dart';

const _kBaudRates = [9600, 19200, 38400, 57600, 115200, 230400, 250000];

class ConnectResult {
  final bool mock;
  final String? port;
  final int baud;
  const ConnectResult.mock() : mock = true, port = null, baud = 115200;
  const ConnectResult.serial(this.port, this.baud) : mock = false;
}

Future<ConnectResult?> showConnectDialog(
  BuildContext context, {
  int initialBaud = 115200,
}) {
  return showDialog<ConnectResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ConnectDialog(initialBaud: initialBaud),
  );
}

class _ConnectDialog extends StatefulWidget {
  final int initialBaud;
  const _ConnectDialog({this.initialBaud = 115200});

  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  List<String> _ports = [];
  String? _selectedPort;
  late int _baud;
  bool _scanning = false;
  bool _serialUnavailable = false;

  @override
  void initState() {
    super.initState();
    _baud = widget.initialBaud;
    _scan();
  }

  void _scan() {
    setState(() => _scanning = true);
    try {
      final ports = GrblSerialService.availablePorts();
      setState(() {
        _scanning = false;
        _ports = ports;
        _serialUnavailable = false;
        if (_selectedPort == null || !ports.contains(_selectedPort)) {
          _selectedPort = ports.isNotEmpty ? ports.first : null;
        }
      });
    } catch (_) {
      setState(() {
        _scanning = false;
        _serialUnavailable = true;
        _ports = [];
        _selectedPort = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.usb, size: 18, color: cs.onSurface.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text('Connect to Machine',
            style: TextStyle(color: cs.onSurface, fontSize: 15)),
        const Spacer(),
        IconButton(
          icon: _scanning
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: cs.onSurface.withValues(alpha: 0.5)))
              : Icon(Icons.refresh, size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
          onPressed: _scanning ? null : _scan,
          tooltip: 'Scan ports',
          visualDensity: VisualDensity.compact,
        ),
      ]),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(
              label: 'Port',
              cs: cs,
              child: _serialUnavailable
                  ? _hint('libserialport not installed', cs)
                  : _ports.isEmpty
                      ? _hint('No ports found — plug in device and scan ↺', cs)
                      : DropdownButton<String>(
                          value: _selectedPort,
                          dropdownColor: cs.surfaceContainerHigh,
                          style: TextStyle(
                              color: cs.onSurface, fontSize: 13),
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: _ports
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedPort = v),
                        ),
            ),
            const SizedBox(height: 10),
            _Row(
              label: 'Baud rate',
              cs: cs,
              child: DropdownButton<int>(
                value: _baud,
                dropdownColor: cs.surfaceContainerHigh,
                style:
                    TextStyle(color: cs.onSurface, fontSize: 13),
                underline: const SizedBox(),
                isExpanded: true,
                items: _kBaudRates
                    .map((b) => DropdownMenuItem(
                          value: b,
                          child: Text('$b'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _baud = v!),
              ),
            ),
            if (!_serialUnavailable) ...[
              const SizedBox(height: 12),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 4),
              Text(
                'Connect (mock) simulates GRBL without hardware.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
      actionsPadding:
          const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, const ConnectResult.mock()),
          child: const Text('Connect (mock)'),
        ),
        FilledButton.icon(
          onPressed: _selectedPort == null || _serialUnavailable
              ? null
              : () => Navigator.pop(
                    context,
                    ConnectResult.serial(_selectedPort!, _baud),
                  ),
          icon: const Icon(Icons.usb, size: 14),
          label: const Text('Connect'),
        ),
      ],
    );
  }

  Widget _hint(String text, ColorScheme cs) => Text(
        text,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final Widget child;
  final ColorScheme cs;
  const _Row({required this.label, required this.child, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ),
        Expanded(child: child),
      ],
    );
  }
}
