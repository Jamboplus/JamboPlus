import 'dart:convert';

import 'package:shelf/shelf.dart';

Response jsonResponse(
  Object? body, {
  int statusCode = 200,
  Map<String, String>? headers,
}) {
  return Response(
    statusCode,
    body: body == null ? null : jsonEncode(body),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      ...?headers,
    },
  );
}

Response errorResponse(int status, String message, {Object? details}) {
  return jsonResponse(
    {
      'error': message,
      if (details != null) 'details': details,
    },
    statusCode: status,
  );
}

Future<Map<String, dynamic>> readJsonBody(Request request) async {
  final raw = await request.readAsString();
  if (raw.trim().isEmpty) return {};
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('Expected JSON object');
  }
  return decoded;
}

String? bearerToken(Request request) {
  final auth = request.headers['Authorization'] ?? request.headers['authorization'];
  if (auth == null) return null;
  const prefix = 'Bearer ';
  if (!auth.startsWith(prefix)) return null;
  return auth.substring(prefix.length).trim();
}
