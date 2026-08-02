import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../config/env.dart';

class AdminClaims {
  AdminClaims({required this.adminId, required this.email, required this.role});

  final String adminId;
  final String email;
  final String role;

  factory AdminClaims.fromPayload(Map<String, dynamic> payload) {
    return AdminClaims(
      adminId: payload['sub'] as String,
      email: payload['email'] as String? ?? '',
      role: payload['role'] as String? ?? 'admin',
    );
  }
}

String issueAdminToken(Env env, AdminClaims claims) {
  final jwt = JWT({
    'sub': claims.adminId,
    'email': claims.email,
    'role': claims.role,
  });
  return jwt.sign(
    SecretKey(env.jwtSecret),
    expiresIn: const Duration(hours: 24),
  );
}

AdminClaims verifyAdminToken(Env env, String token) {
  final jwt = JWT.verify(token, SecretKey(env.jwtSecret));
  final payload = jwt.payload as Map<String, dynamic>;
  return AdminClaims.fromPayload(payload);
}
