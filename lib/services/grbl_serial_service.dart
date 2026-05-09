import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../models/svg_document.dart';
import 'grbl_service.dart';
import 'gcode_generator.dart';

class GrblSerialService extends GrblService {
  SerialPort? _port;
  StreamSubscription<Uint8List>? _sub;
  Timer? _pollTimer;
  String _rxBuf = '';

  // Job streaming
  bool _jobPaused = false;
  bool _jobCancelled = false;
  bool _framingCancelled = false;
  Completer<bool>? _ackCompleter;

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

      final reader = SerialPortReader(_port!);
      _sub = reader.stream.listen(_onData, onError: (_) => disconnect());

      // Start status polling at 5 Hz
      _pollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _sendRaw('?');
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
    _framingCancelled = true;
    _ackCompleter?.complete(false);
    _ackCompleter = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _sub?.cancel();
    _sub = null;
    try { _port?.close(); } catch (_) {}
    _port?.dispose();
    _port = null;
    connected = false;
    _jobPaused = false;
    _jobCancelled = false;
    jobProgress = 0;
    jobCurrentLabel = '';
    setMachineStatus(MachineStatus.idle);
  }

  // ── Serial I/O ───────────────────────────────────────────────────

  void _sendRaw(String cmd) {
    if (_port == null || !_port!.isOpen) return;
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
    } else if (line == 'ok') {
      _ackCompleter?.complete(true);
      _ackCompleter = null;
    } else if (line.startsWith('error:')) {
      _ackCompleter?.complete(false);
      _ackCompleter = null;
    } else if (line.startsWith('ALARM:')) {
      setMachineStatus(MachineStatus.alarm);
    }
  }

  void _parseStatus(String line) {
    // <Idle|MPos:0.000,0.000,0.000|...>  or  <Idle|WPos:0.000,...>
    final stRe = RegExp(r'<(\w+)[|>]');
    final posRe = RegExp(r'(?:MPos|WPos):([-\d.]+),([-\d.]+),([-\d.]+)');
    final stM = stRe.firstMatch(line);
    final posM = posRe.firstMatch(line);
    if (stM != null) {
      status = _parseStatusStr(stM.group(1)!);
    }
    if (posM != null) {
      x = double.tryParse(posM.group(1)!) ?? x;
      y = double.tryParse(posM.group(2)!) ?? y;
      z = double.tryParse(posM.group(3)!) ?? z;
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
    _sendRaw('\$H');
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
    _streamJob(document);
  }

  void _streamJob(SvgDocument document) async {
    final gcode = GcodeGenerator.generate(document, '');
    final lines = gcode
        .split('\n')
        .map((l) => l.contains(';')
            ? l.substring(0, l.indexOf(';')).trim()
            : l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

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
    if (!_jobCancelled) {
      // Natural completion: transition to idle and mark done in one notification.
      _jobCancelled = false;
      status = MachineStatus.idle;
      jobJustCompleted = true;
      notifyListeners();
    } else {
      _jobCancelled = false;
      setMachineStatus(MachineStatus.idle);
    }
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
    _ackCompleter?.complete(false);
    _ackCompleter = null;
    _sendByte(0x18); // GRBL soft reset
  }

  // ── Framing (G0 trace with laser off) ───────────────────────────

  @override
  void startFraming(Rect b) {
    if (isFraming || isJobRunning) return;
    _framingCancelled = false;
    _doFraming(b);
  }

  @override
  void stopFraming() {
    if (!isFraming) return;
    _framingCancelled = true;
    _ackCompleter?.complete(false);
    _ackCompleter = null;
    isFraming = false;
    notifyListeners();
  }

  void _doFraming(Rect b) async {
    String f(double v) => v.toStringAsFixed(3);
    final lines = [
      'M5 S0',
      'G0 X${f(b.left)} Y${f(b.top)}',
      'G0 X${f(b.right)} Y${f(b.top)}',
      'G0 X${f(b.right)} Y${f(b.bottom)}',
      'G0 X${f(b.left)} Y${f(b.bottom)}',
      'G0 X${f(b.left)} Y${f(b.top)}',
      'G0 X0 Y0',
    ];

    isFraming = true;
    notifyListeners();

    for (final line in lines) {
      if (_framingCancelled) break;
      _sendRaw(line);
      final ok = await _waitAck();
      if (!ok || _framingCancelled) break;
    }

    _framingCancelled = false;
    isFraming = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
