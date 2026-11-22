import 'package:flutter_test/flutter_test.dart';
import 'package:mis_habitos/core/pin_hasher.dart';

String _hex(String base64Value) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final clean = base64Value.replaceAll('=', '');
  var bits = 0;
  var value = 0;
  final out = StringBuffer();
  for (final c in clean.split('')) {
    value = (value << 6) | chars.indexOf(c);
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.write(((value >> bits) & 0xff).toRadixString(16).padLeft(2, '0'));
    }
  }
  return out.toString();
}

void main() {
  test('PBKDF2-HMAC-SHA256 coincide con el vector de prueba del RFC 7914', () {
    // P = "passwd", S = "salt", c = 1 (primeros 32 bytes).
    final hash = PinHasher.hash('passwd', 'c2FsdA==', 1);
    expect(_hex(hash), '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc');
  });

  test('PBKDF2 con varias iteraciones coincide con hashlib de Python', () {
    // python: hashlib.pbkdf2_hmac('sha256', b'1234', b'0123456789abcdef', 1000)
    final hash = PinHasher.hash('1234', 'MDEyMzQ1Njc4OWFiY2RlZg==', 1000);
    expect(_hex(hash), '96d86bc387622a132a8ec3fa3dbf14b7c25a903339de2db067430a08647c827e');
  });

  test('cada sal es distinta, así el mismo PIN da hashes distintos', () {
    final a = PinHasher.newSalt();
    final b = PinHasher.newSalt();
    expect(a, isNot(b));
    expect(PinHasher.hash('1234', a, 10), isNot(PinHasher.hash('1234', b, 10)));
  });

  test('comparación en tiempo constante', () {
    expect(PinHasher.constantTimeEquals('abc', 'abc'), isTrue);
    expect(PinHasher.constantTimeEquals('abc', 'abd'), isFalse);
    expect(PinHasher.constantTimeEquals('abc', 'abcd'), isFalse);
  });
}
