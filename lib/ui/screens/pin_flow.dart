import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../data/settings_repository.dart';
import '../app_scope.dart';
import '../widgets/pin_entry.dart';

enum PinFlowMode {
  /// Pantalla de acceso: pide el PIN, o lo crea si es la primera vez.
  unlock,

  /// Cambiar PIN: actual → nuevo → confirmación.
  change,
}

enum _Step { loading, verify, create, confirm }

/// Flujo completo del PIN, usado por la pantalla de acceso y por
/// "Cambiar PIN" en ajustes.
class PinFlow extends StatefulWidget {
  const PinFlow({super.key, required this.mode, required this.onDone});

  final PinFlowMode mode;
  final VoidCallback onDone;

  @override
  State<PinFlow> createState() => _PinFlowState();
}

class _PinFlowState extends State<PinFlow> {
  _Step _step = _Step.loading;
  String? _firstPin;
  String? _error;
  bool _success = false;
  DateTime? _lockedUntil;
  Timer? _ticker;

  SettingsRepository get _settings => AppScope.of(context).settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_step == _Step.loading) _load();
  }

  Future<void> _load() async {
    final hasPin = await _settings.hasPin();
    final remaining = await _settings.remainingLock();
    if (!mounted) return;
    setState(() {
      _step = (widget.mode == PinFlowMode.unlock && !hasPin) ? _Step.create : _Step.verify;
    });
    if (remaining != null) _startLock(remaining);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startLock(Duration remaining) {
    _lockedUntil = DateTime.now().add(remaining);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
    _tick();
  }

  void _tick() {
    if (!mounted) return;
    final left = _lockedUntil!.difference(DateTime.now());
    if (left <= Duration.zero) {
      _ticker?.cancel();
      setState(() {
        _lockedUntil = null;
        _error = null;
      });
      return;
    }
    setState(() => _error = 'Demasiados intentos. Espera ${left.inSeconds + 1} s');
  }

  Future<bool> _onCompleted(String pin) async {
    switch (_step) {
      case _Step.loading:
        return false;

      case _Step.verify:
        final result = await _settings.verifyPin(pin);
        if (!mounted) return false;
        switch (result) {
          case PinOk():
            if (widget.mode == PinFlowMode.unlock) {
              _finish();
            } else {
              setState(() {
                _step = _Step.create;
                _error = null;
              });
            }
            return true;
          case PinWrong(:final attemptsLeft):
            setState(() {
              _error =
                  'PIN incorrecto · '
                  '${attemptsLeft == 1 ? 'te queda 1 intento' : 'te quedan $attemptsLeft intentos'}';
            });
            return false;
          case PinLocked(:final remaining):
            _startLock(remaining);
            return false;
        }

      case _Step.create:
        setState(() {
          _firstPin = pin;
          _step = _Step.confirm;
          _error = null;
        });
        return true;

      case _Step.confirm:
        if (pin != _firstPin) {
          setState(() {
            _firstPin = null;
            _step = _Step.create;
            _error = 'Los PIN no coinciden. Inténtalo de nuevo';
          });
          return false;
        }
        await _settings.setPin(pin);
        if (!mounted) return true;
        _finish();
        return true;
    }
  }

  void _finish() {
    setState(() {
      _success = true;
      _error = null;
    });
    // Pequeña pausa para ver el candado abierto.
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) widget.onDone();
    });
  }

  ({String title, String subtitle}) get _texts {
    final unlock = widget.mode == PinFlowMode.unlock;
    return switch (_step) {
      _Step.loading => (title: '', subtitle: ''),
      _Step.verify =>
        unlock
            ? (title: 'Mis hábitos', subtitle: 'Ingresa tu PIN para continuar')
            : (title: 'Cambiar PIN', subtitle: 'Primero ingresa tu PIN actual'),
      _Step.create =>
        unlock
            ? (title: 'Crea tu PIN', subtitle: 'Elige 4 dígitos para proteger tus hábitos')
            : (title: 'Nuevo PIN', subtitle: 'Elige 4 dígitos que recuerdes'),
      _Step.confirm => (title: 'Confirma tu PIN', subtitle: 'Escríbelo una vez más'),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _Step.loading) return const SizedBox.shrink();
    final texts = _texts;
    return PinEntry(
      key: ValueKey(_step),
      title: texts.title,
      subtitle: texts.subtitle,
      icon: _success
          ? Icons.lock_open_rounded
          : (_step == _Step.verify ? Icons.lock_rounded : Icons.password_rounded),
      error: _error,
      enabled: _lockedUntil == null && !_success,
      length: SettingsRepository.pinLength,
      onCompleted: _onCompleted,
    );
  }
}

/// Pantalla 1: acceso. Se dibuja encima de toda la app mientras está
/// bloqueada.
class LockScreen extends StatelessWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: PinFlow(mode: PinFlowMode.unlock, onDone: onUnlocked),
          ),
        ),
      ),
    );
  }
}

/// Cambiar el PIN desde ajustes.
class ChangePinScreen extends StatelessWidget {
  const ChangePinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: PinFlow(
              mode: PinFlowMode.change,
              onDone: () {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(context).pop();
                messenger.showSnackBar(const SnackBar(content: Text('PIN actualizado')));
              },
            ),
          ),
        ),
      ),
    );
  }
}
