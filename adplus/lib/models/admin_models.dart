import 'package:flutter/material.dart';

class AdminNavItem {
  final String id;
  final String label;
  final IconData icon;

  const AdminNavItem(this.id, this.label, this.icon);
}

/// Accepts ISO and admin-typed dates like `17/09/2026` or `17/09/2026T00:00:00.000Z`.
DateTime? parseAdminDate(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;

  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;

  final datePart = s.split(RegExp(r'[T\s]')).first.trim();

  final dmy = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$').firstMatch(datePart);
  if (dmy != null) {
    final a = int.parse(dmy.group(1)!);
    final b = int.parse(dmy.group(2)!);
    final y = int.parse(dmy.group(3)!);
    final day = a > 12 ? a : b > 12 ? b : a;
    final month = a > 12 ? b : b > 12 ? a : b;
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return DateTime(y, month, day);
    }
  }

  final ymd = RegExp(r'^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})$').firstMatch(datePart);
  if (ymd != null) {
    final y = int.parse(ymd.group(1)!);
    final month = int.parse(ymd.group(2)!);
    final day = int.parse(ymd.group(3)!);
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return DateTime(y, month, day);
    }
  }

  return null;
}

String? toAdminExpiryIso(String? raw) {
  final d = parseAdminDate(raw);
  if (d == null) return null;
  return DateTime.utc(d.year, d.month, d.day).toIso8601String();
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isConnection =>
      message.contains('haijaunganishwa') || message.contains('mtandao');

  @override
  String toString() => message;
}
