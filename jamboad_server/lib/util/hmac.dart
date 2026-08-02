import 'dart:convert';

import 'package:crypto/crypto.dart';

String hmacSha256Hex(String secret, String message) {
  final key = utf8.encode(secret);
  final bytes = utf8.encode(message);
  return Hmac(sha256, key).convert(bytes).toString();
}
