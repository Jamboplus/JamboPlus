import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Signs app API requests: HMAC-SHA256(secret, timestamp + METHOD + path).
String jamboAppSignature({
  required String secret,
  required int timestampSeconds,
  required String method,
  required String path,
}) {
  final payload = '$timestampSeconds${method.toUpperCase()}$path';
  final key = utf8.encode(secret);
  final bytes = utf8.encode(payload);
  final digest = Hmac(sha256, key).convert(bytes);
  return digest.toString();
}

int jamboTimestampSeconds() =>
    DateTime.now().millisecondsSinceEpoch ~/ 1000;
