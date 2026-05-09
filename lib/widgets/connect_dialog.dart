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

Future<ConnectResult?> showConnectDialog(BuildContext context) {
  return showDialog<ConnectResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _ConnectDialog(),
  );
}

class _ConnectDialog extends StatefulWidget {
  const _ConnectDialog();

  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  List<String> _ports = [];
  String? _selectedPort;
  int _baud = 115200;
  bool _scanning = false;
  bool _serialUnavailable = false;

  @override
  void initState() {
    super.initState();
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
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Row(children: [
        const Icon(Icons.usb, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        const Text('Connect to Machine',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        const Spacer(),
        IconButton(
          icon: _scanning
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: Colors.white54))
              : const Icon(Icons.refresh, size: 16, color: Colors.white54),
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
            // Serial port row
            _Row(
              label: 'Port',
              child: _serialUnavailable
                  ? _hint('libserialport not installed')
                  : _ports.isEmpty
                      ? _hint('No ports found — plug in device and scan ↺')
                      : DropdownButton<String>(
                          value: _selectedPort,
                          dropdownColor: Colors.grey[850],
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
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
            // Baud rate row
            _Row(
              label: 'Baud rate',
              child: DropdownButton<int>(
                value: _baud,
                dropdownColor: Colors.grey[850],
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13),
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
              const Divider(color: Colors.white12),
              const SizedBox(height: 4),
              Text(
                'Connect (mock) simulates GRBL without hardware.',
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
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
          style: TextButton.styleFrom(foregroundColor: Colors.grey[500]),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, const ConnectResult.mock()),
          style:
              TextButton.styleFrom(foregroundColor: Colors.grey[400]),
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
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            disabledBackgroundColor: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _hint(String text) => Text(
        text,
        style: TextStyle(color: Colors.grey[600], fontSize: 11),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final Widget child;
  const _Row({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ),
        Expanded(child: child),
      ],
    );
  }
}
