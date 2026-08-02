import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

final _random = Random.secure();

String hashPassword(String password) {
  final saltBytes = List<int>.generate(16, (_) => _random.nextInt(256));
  final salt = base64Url.encode(saltBytes);
  final hash = _sha256('$salt:$password');
  return '$salt:$hash';
}

bool verifyPassword(String password, String stored) {
  final sep = stored.indexOf(':');
  if (sep <= 0) return false;
  final salt = stored.substring(0, sep);
  final expected = stored.substring(sep + 1);
  final actual = _sha256('$salt:$password');
  return _constantTimeEquals(expected, actual);
}

String _sha256(String input) {
  return sha256.convert(utf8.encode(input)).toString();
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
