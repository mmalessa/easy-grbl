import 'package:flutter/material.dart';
import '../machines/common_settings.dart';
import '../machines/laser/widgets/laser_settings_section.dart';
import '../machines/machine_mode.dart';
import '../machines/machine_settings.dart';
import '../machines/mill/widgets/mill_settings_section.dart';
import '../services/grbl_service.dart';
import 'settings_form_fields.dart';

const _kBaudRates = [9600, 19200, 38400, 57600, 115200, 230400, 250000];

Future<MachineSettings?> showMachineSettingsDialog(
  BuildContext context,
  MachineSettings current,
  GrblService grbl,
) {
  return showDialog<MachineSettings>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _MachineSettingsDialog(current: current, grbl: grbl),
  );
}

class _MachineSettingsDialog extends StatefulWidget {
  final MachineSettings current;
  final GrblService grbl;
  const _MachineSettingsDialog({required this.current, required this.grbl});

  @override
  State<_MachineSettingsDialog> createState() => _MachineSettingsDialogState();
}

class _MachineSettingsDialogState extends State<_MachineSettingsDialog> {
  // The working mode is changed only via Machine → Mode, not in this dialog.
  late final MachineType _machineType = widget.current.machineType;
  late final LaserSettingsForm _laserForm = LaserSettingsForm(widget.current.laser);
  late final MillSettingsForm _millForm = MillSettingsForm(widget.current.mill);
  late int _baudRate = widget.current.common.defaultBaudRate;

  bool _queryingDevice = false;
  MachineType? _deviceMachineType;

  @override
  void initState() {
    super.initState();
    if (widget.grbl.connected) {
      _queryingDevice = true;
      widget.grbl.queryMachineType().then((type) {
        if (!mounted) return;
        setState(() {
          _deviceMachineType = type;
          _queryingDevice = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _laserForm.dispose();
    _millForm.dispose();
    super.dispose();
  }

  bool get _isValid => _machineType == MachineType.laser
      ? _laserForm.isValid
      : _millForm.isValid;

  // Both parts are rebuilt from their forms (as the original dialog did), so
  // the inactive mode's values round-trip through the same parse/clamp.
  MachineSettings _buildResult() => widget.current.copyWith(
        common: CommonSettings(defaultBaudRate: _baudRate),
        laser: _laserForm.result(widget.current.laser),
        mill: _millForm.result(widget.current.mill),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([_laserForm, _millForm]),
      builder: (context, _) => AlertDialog(
        title: Row(children: [
          Icon(Icons.settings, size: 18, color: cs.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text('Machine Settings',
              style: TextStyle(color: cs.onSurface, fontSize: 15)),
        ]),
        content: SizedBox(
          width: 570,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _connectionStatusRow(cs),
                const SizedBox(height: 20),
                if (_machineType == MachineType.laser)
                  LaserSettingsSection(form: _laserForm)
                else
                  MillSettingsSection(form: _millForm),
                const SizedBox(height: 20),
                settingsSectionHeader('CONNECTION', cs),
                _baudRateRow(cs),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed:
                _isValid ? () => Navigator.pop(context, _buildResult()) : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _connectionStatusRow(ColorScheme cs) {
    final connected = widget.grbl.connected;
    final statusColor = connected ? const Color(0xFF388E3C) : cs.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            connected ? 'Connected' : 'Disconnected',
            style: TextStyle(
                color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (connected) ...[
            const SizedBox(width: 10),
            Container(width: 1, height: 12, color: cs.outlineVariant),
            const SizedBox(width: 10),
            if (_queryingDevice)
              Text('Detecting device type…',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))
            else if (_deviceMachineType == null)
              Text('Device type unknown',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))
            else ...[
              Icon(
                _deviceMachineType == MachineType.laser
                    ? Icons.flash_on
                    : Icons.build,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Device configured as: ${_deviceMachineType!.profile.displayName}',
                style: TextStyle(
                    color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _baudRateRow(ColorScheme cs) => Row(
        children: [
          settingsFieldLabel('Default baud rate', cs),
          const Spacer(),
          DropdownButton<int>(
            value: _baudRate,
            dropdownColor: cs.surfaceContainerHigh,
            style: TextStyle(color: cs.onSurface, fontSize: 13),
            underline: const SizedBox(),
            items: _kBaudRates
                .map((b) => DropdownMenuItem(value: b, child: Text('$b')))
                .toList(),
            onChanged: (v) => setState(() => _baudRate = v!),
          ),
        ],
      );
}
