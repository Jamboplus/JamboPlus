import 'package:flutter/material.dart';

class AdminNavItem {
  final String id;
  final String label;
  final IconData icon;

  const AdminNavItem(this.id, this.label, this.icon);
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
