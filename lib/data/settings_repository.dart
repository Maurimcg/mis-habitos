import 'dart:isolate';

import 'package:material_ui/material_ui.dart' show ThemeMode;

import '../core/pin_hasher.dart';
import 'database.dart';

/// Resultado de verificar un PIN.
sealed class PinCheck {
  const PinCheck();
}

class PinOk extends PinCheck {
  const PinOk();
}

class PinWrong extends PinCheck {
  const PinWrong(this.attemptsLeft);
  final int attemptsLeft;
}

class PinLocked extends PinCheck {
  const PinLocked(this.remaining);
  final Duration remaining;
}

/// Función que deriva el hash del PIN. Se puede reemplazar en las pruebas.
typedef PinHashFunction = Future<String> Function(String pin, String salt, int iterations);

/// Por defecto el hash se calcula en otro isolate para no congelar la UI.
Future<String> _hashInIsolate(String pin, String salt, int iterations) =>
    Isolate.run(() => PinHasher.hash(pin, salt, iterations));

/// Preferencias guardadas en la tabla `app_settings` y lógica del PIN.
class SettingsRepository {
  SettingsRepository(
    this._db, {
    DateTime Function()? clock,
    PinHashFunction? hashFunction,
    this.iterations = PinHasher.defaultIterations,
  }) : _clock = clock ?? DateTime.now,
       _hash = hashFunction ?? _hashInIsolate;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final PinHashFunction _hash;
  final int iterations;

  /// Intentos fallidos permitidos antes de bloquear.
  static const maxAttempts = 5;

  /// Tiempo de bloqueo tras agotar los intentos.
  static const lockDuration = Duration(seconds: 30);

  static const pinLength = 4;

  static const _kPinHash = 'pin_hash';
  static const _kPinSalt = 'pin_salt';
  static const _kPinIterations = 'pin_iterations';
  static const _kFailedAttempts = 'failed_attempts';
  static const _kLockedUntil = 'locked_until';
  static const _kThemeMode = 'theme_mode';

  // ---------------------------------------------------------------------------
  // Clave-valor
  // ---------------------------------------------------------------------------

  Future<String?> _get(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> _watch(String key) => (_db.select(
    _db.appSettings,
  )..where((s) => s.key.equals(key))).watchSingleOrNull().map((row) => row?.value);

  Future<void> _set(String key, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));

  Future<void> _remove(Iterable<String> keys) =>
      (_db.delete(_db.appSettings)..where((s) => s.key.isIn(keys))).go();

  // ---------------------------------------------------------------------------
  // Tema
  // ---------------------------------------------------------------------------

  Stream<ThemeMode> watchThemeMode() =>
      _watch(_kThemeMode).map((value) => ThemeMode.values.asNameMap()[value] ?? ThemeMode.system);

  Future<void> setThemeMode(ThemeMode mode) => _set(_kThemeMode, mode.name);

  // ---------------------------------------------------------------------------
  // PIN
  // ---------------------------------------------------------------------------

  static bool isValidPin(String pin) => pin.length == pinLength && RegExp(r'^\d+$').hasMatch(pin);

  Future<bool> hasPin() async => (await _get(_kPinHash)) != null;

  /// Crea o reemplaza el PIN (guarda solo sal + hash).
  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('El PIN debe tener $pinLength dígitos');
    final salt = PinHasher.newSalt();
    final hash = await _hash(pin, salt, iterations);
    await _db.transaction(() async {
      await _set(_kPinSalt, salt);
      await _set(_kPinHash, hash);
      await _set(_kPinIterations, '$iterations');
      await _remove([_kFailedAttempts, _kLockedUntil]);
    });
  }

  /// Tiempo que falta para poder intentar de nuevo, o `null` si no hay bloqueo.
  Future<Duration?> remainingLock() async {
    final raw = await _get(_kLockedUntil);
    if (raw == null) return null;
    final remaining = DateTime.parse(raw).difference(_clock());
    return remaining > Duration.zero ? remaining : null;
  }

  /// Verifica el PIN y lleva la cuenta de intentos fallidos.
  ///
  /// El contador y el bloqueo se guardan en la base de datos, así cerrar y
  /// abrir la app no reinicia los intentos.
  Future<PinCheck> verifyPin(String pin) async {
    final locked = await remainingLock();
    if (locked != null) return PinLocked(locked);

    final salt = await _get(_kPinSalt);
    final expected = await _get(_kPinHash);
    if (salt == null || expected == null) throw StateError('No hay PIN configurado');
    final rounds = int.tryParse(await _get(_kPinIterations) ?? '') ?? iterations;

    final actual = await _hash(pin, salt, rounds);
    if (PinHasher.constantTimeEquals(actual, expected)) {
      await _remove([_kFailedAttempts, _kLockedUntil]);
      return const PinOk();
    }

    final failed = (int.tryParse(await _get(_kFailedAttempts) ?? '') ?? 0) + 1;
    if (failed >= maxAttempts) {
      await _db.transaction(() async {
        await _set(_kLockedUntil, _clock().add(lockDuration).toIso8601String());
        await _remove([_kFailedAttempts]);
      });
      return const PinLocked(lockDuration);
    }
    await _set(_kFailedAttempts, '$failed');
    return PinWrong(maxAttempts - failed);
  }
}
