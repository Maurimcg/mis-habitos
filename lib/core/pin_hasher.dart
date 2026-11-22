import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Deriva y verifica el PIN con PBKDF2-HMAC-SHA256 y una sal aleatoria.
///
/// El PIN nunca se guarda en texto plano: en la base de datos solo quedan
/// la sal, el número de iteraciones y el resultado.
class PinHasher {
  const PinHasher._();

  /// Iteraciones por defecto. Se guardan junto al hash para poder subirlas
  /// en el futuro sin invalidar los PIN ya creados.
  static const defaultIterations = 120000;

  static String newSalt() {
    final random = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  /// PBKDF2 con un solo bloque de 32 bytes (el tamaño de SHA-256).
  static String hash(String pin, String saltBase64, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    final salt = base64Decode(saltBase64);
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(block);
    for (var i = 1; i < iterations; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return base64Encode(result);
  }

  /// Compara en tiempo constante para no filtrar información por tiempos.
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
