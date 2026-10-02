import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../models/svg_document.dart';
import '../machines/machine_mode.dart';
import 'grbl_service.dart';
import 'gcode_format.dart';
import '../machines/gcode/gcode_generator.dart';

class GrblSerialService extends GrblService {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _sub;
  Timer? _pollTimer;
  String _rxBuf = '';

  // Job streaming
  bool _jobPaused = false;
  bool _jobCancelled = false;
  bool _pendingUnlock = false;
  Completer<bool>? _ackCompleter;

  // Cached work-coordinate offset (updated when GRBL sends WCO in status)
  double _wcox = 0, _wcoy = 0, _wcoz = 0;

  // '$$' settings query (used to read the device's actual $32 laser-mode flag)
  Map<String, String> _settingsBuffer = {};
  Completer<Map<String, String>>? _settingsCompleter;

  @override
  bool get isJobPaused => _jobPaused;

  // ── Available ports ──────────────────────────────────────────────

  /// Returns available /dev/tty* port names, filtered to likely GRBL ports.
  static List<String> availablePorts() {
    try {
      return SerialPort.availablePorts;
    } catch (_) {
      return [];
    }
  }

  // ── Connection ───────────────────────────────────────────────────

  /// Opens the serial port. Returns true on success, false on failure.
  Future<bool> connectSerial(String portName, int baud) async {
    try {
      _port = SerialPort(portName);
      if (!_port!.openReadWrite()) return false;

      final cfg = SerialPortConfig()
        ..baudRate = baud
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1
        ..setFlowControl(SerialPortFlowControl.none);
      _port!.config = cfg;
      cfg.dispose();

      _reader = SerialPortReader(_port!);
      _sub = _reader!.stream.listen(_onData, onError: (_) => disconnect());

      // Start status polling at 5 Hz.
      // '?' is a GRBL real-time command — send it as a bare byte, NOT with '\n'.
      // Sending '?\n' would cause GRBL to reply with both a status report AND
      // a spurious 'ok' for the empty command, which prematurely fires _ackCompleter.
      _pollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _sendByte(0x3F); // '?'
      });

      connected = true;
      notifyListeners();
      return true;
    } catch (_) {
      _port?.close();
      _port?.dispose();
      _port = null;
      return false;
    }
  }

  @override
  void disconnect() {
    _jobCancelled = true;
    _ackCompleter?.complete(false);
    _ackCompleter = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _sub?.cancel();
    _sub = null;
    try { _reader?.close(); } catch (_) {}
    _reader = null;
    try { _port?.close(); } catch (_) {}
    try { _port?.dispose(); } catch (_) {}
    _port = null;
    connected = false;
    _jobPaused = false;
    _jobCancelled = false;
    _pendingUnlock = false;
    jobProgress = 0;
    jobCurrentLabel = '';
    _wcox = 0; _wcoy = 0; _wcoz = 0;
    _settingsCompleter?.complete(_settingsBuffer);
    _settingsCompleter = null;
    setMachineStatus(MachineStatus.idle);
  }

  // ── Settings query ───────────────────────────────────────────────

  /// Sends '$$' and parses the '$32=' line to determine whether the
  /// device's firmware is configured for laser mode.
  @override
  Future<MachineType?> queryMachineType() async {
    // `$$` mid-job would steal the streaming loop's acks.
    if (_port == null || !_port!.isOpen || isJobActive) return null;
    _settingsBuffer = {};
    final completer = Completer<Map<String, String>>();
    _settingsCompleter = completer;
    _sendRaw('\$\$');
    final settings = await completer.future
        .timeout(const Duration(seconds: 3), onTimeout: () => _settingsBuffer);
    if (identical(_settingsCompleter, completer)) _settingsCompleter = null;
    final laserFlag = settings['32'];
    if (laserFlag == null) return null;
    return laserFlag.trim() == '1' ? MachineType.laser : MachineType.mill;
  }

  /// Writes GRBL's $32 laser-mode setting on the device.
  @override
  Future<bool> setDeviceLaserMode(bool enabled) async {
    if (_port == null || !_port!.isOpen || isJobActive) return false;
    _sendRaw('\$32=${enabled ? 1 : 0}');
    return _waitAck();
  }

  // ── Serial I/O ───────────────────────────────────────────────────

  void _sendRaw(String cmd) {
    if (_port == null || !_port!.isOpen) return;
    logTx(cmd);
    try {
      _port!.write(Uint8List.fromList('$cmd\n'.codeUnits));
    } catch (_) {
      disconnect();
    }
  }

  void _sendByte(int byte) {
    if (_port == null || !_port!.isOpen) return;
    try {
      _port!.write(Uint8List.fromList([byte]));
    } catch (_) {}
  }

  void _onData(Uint8List data) {
    _rxBuf += String.fromCharCodes(data);
    while (_rxBuf.contains('\n')) {
      final idx = _rxBuf.indexOf('\n');
      final line = _rxBuf.substring(0, idx).trim();
      _rxBuf = _rxBuf.substring(idx + 1);
      if (line.isNotEmpty) _processLine(line);
    }
  }

  void _processLine(String line) {
    if (line.startsWith('<')) {
      _parseStatus(line);
      return;
    }
    logRx(line);

    final settingM = _settingRe.firstMatch(line);
    if (settingM != null && _settingsCompleter != null) {
      _settingsBuffer[settingM.group(1)!] = settingM.group(2)!;
      return;
    }

    if (line.startsWith('Grbl ')) {
      // GRBL startup message — fired after soft reset or power-on.
      // If we triggered the reset via Stop, automatically unlock alarm.
      if (_pendingUnlock) {
        _pendingUnlock = false;
        _sendRaw('\$X');
      }
    } else if (line == 'ok') {
      if (_settingsCompleter != null && !_settingsCompleter!.isCompleted) {
        _settingsCompleter!.complete(Map.of(_settingsBuffer));
      }
      _ackCompleter?.complete(true);
      _ackCompleter = null;
    } else if (line.startsWith('error:')) {
      _ackCompleter?.complete(false);
      _ackCompleter = null;
    } else if (line.startsWith('ALARM:')) {
      setMachineStatus(MachineStatus.alarm);
    }
  }

  static final _settingRe = RegExp(r'^\$(\d+)=(.+)$');
  static final _stRe   = RegExp(r'<(\w+)[|>]');
  static final _wposRe = RegExp(r'WPos:([-\d.]+),([-\d.]+),([-\d.]+)');
  static final _mposRe = RegExp(r'MPos:([-\d.]+),([-\d.]+),([-\d.]+)');
  static final _wcoRe  = RegExp(r'WCO:([-\d.]+),([-\d.]+),([-\d.]+)');

  void _parseStatus(String line) {
    // GRBL 1.1 sends either:
    //   <Idle|WPos:x,y,z|...>               ($10=1)
    //   <Idle|MPos:x,y,z|...|WCO:ox,oy,oz> ($10=0, WCO only when changed)
    // We always want work-space position (WPos) for the crosshair.

    final stM = _stRe.firstMatch(line);
    if (stM != null) status = _parseStatusStr(stM.group(1)!);

    // Update cached WCO whenever GRBL includes it (sent only when it changes).
    final wcoM = _wcoRe.firstMatch(line);
    if (wcoM != null) {
      _wcox = double.tryParse(wcoM.group(1)!) ?? _wcox;
      _wcoy = double.tryParse(wcoM.group(2)!) ?? _wcoy;
      _wcoz = double.tryParse(wcoM.group(3)!) ?? _wcoz;
    }

    final wposM = _wposRe.firstMatch(line);
    if (wposM != null) {
      x = double.tryParse(wposM.group(1)!) ?? x;
      y = double.tryParse(wposM.group(2)!) ?? y;
      z = double.tryParse(wposM.group(3)!) ?? z;
    } else {
      final mposM = _mposRe.firstMatch(line);
      if (mposM != null) {
        x = (double.tryParse(mposM.group(1)!) ?? 0) - _wcox;
        y = (double.tryParse(mposM.group(2)!) ?? 0) - _wcoy;
        z = (double.tryParse(mposM.group(3)!) ?? 0) - _wcoz;
      }
    }

    notifyListeners();
  }

  MachineStatus _parseStatusStr(String s) => switch (s.toLowerCase()) {
        'idle' => MachineStatus.idle,
        'run' => MachineStatus.run,
        'jog' => MachineStatus.jog,
        'home' || 'homing' => MachineStatus.homing,
        'alarm' => MachineStatus.alarm,
        'hold' || 'hold:0' || 'hold:1' => MachineStatus.hold,
        _ => status,
      };

  // ── Machine commands ─────────────────────────────────────────────

  @override
  void jog(double dx, double dy, double dz) {
    if (!isIdle) return;
    final parts = <String>[];
    if (dx != 0) parts.add('X${dx.toStringAsFixed(3)}');
    if (dy != 0) parts.add('Y${dy.toStringAsFixed(3)}');
    if (dz != 0) parts.add('Z${dz.toStringAsFixed(3)}');
    if (parts.isEmpty) return;
    final f = (stepMm * 60 * 10).round().clamp(100, 10000);
    _sendRaw('\$J=G91 G21 ${parts.join(' ')} F$f');
  }

  @override
  void homeAll() {
    if (!connected) return;
    _sendRaw('G0 X0 Y0 Z0');
  }

  @override
  void setOrigin() {
    if (!isIdle) return;
    _sendRaw('G10 L20 P1 X0 Y0 Z0');
    x = 0; y = 0; z = 0;
    notifyListeners();
  }

  // ── Job execution (G-code streaming) ────────────────────────────

  @override
  void startJob(SvgDocument document) {
    if (!isIdle) return;
    _jobCancelled = false;
    _jobPaused = false;
    final gcode = GcodeGenerator.generate(document, '', machineSettings);
    final lines = stripGcodeComments(gcode);
    if (lines.isNotEmpty) _streamLines(lines);
  }

  @override
  void startLines(List<String> lines) {
    if (!isIdle) return;
    _jobCancelled = false;
    _jobPaused = false;
    _streamLines(lines);
  }

  void _streamLines(List<String> lines) async {
    if (lines.isEmpty) return;

    jobProgress = 0;
    jobCurrentStep = 0;
    jobCurrentLabel = '';
    setMachineStatus(MachineStatus.run);

    for (var i = 0; i < lines.length && !_jobCancelled; i++) {
      // Handle pause
      while (_jobPaused && !_jobCancelled) {
        await Future.delayed(const Duration(milliseconds: 80));
      }
      if (_jobCancelled) break;

      final line = lines[i];
      jobCurrentLabel = line;
      jobCurrentStep = i;
      jobProgress = i / lines.length;
      notifyListeners();

      _sendRaw(line);

      final ok = await _waitAck();
      if (!ok && !_jobCancelled) break;
    }

    jobProgress = 0.0;
    jobCurrentLabel = '';
    _jobPaused = false;
    _jobCancelled = false;
    setMachineStatus(MachineStatus.idle);
  }

  Future<bool> _waitAck() {
    _ackCompleter = Completer<bool>();
    return _ackCompleter!.future
        .timeout(const Duration(seconds: 10), onTimeout: () => false);
  }

  @override
  void pauseJob() {
    if (!isJobRunning || _jobPaused) return;
    _jobPaused = true;
    _sendByte(0x21); // GRBL '!' feed hold
    notifyListeners();
  }

  @override
  void resumeJob() {
    if (!isJobRunning || !_jobPaused) return;
    _jobPaused = false;
    _sendByte(0x7E); // GRBL '~' cycle start
    notifyListeners();
  }

  @override
  void stopJob() {
    if (!isJobRunning && !_jobPaused) return;
    _jobCancelled = true;
    _jobPaused = false;
    _pendingUnlock = true;
    _ackCompleter?.complete(false);
    _ackCompleter = null;
    jobProgress = 0.0;
    jobCurrentLabel = '';
    notifyListeners();
    _sendByte(0x18); // GRBL soft reset — GRBL will reply with "Grbl x.x..." then we send $X
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
