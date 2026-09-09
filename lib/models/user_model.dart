enum PackageType { free, premium }

class UserModel {
  const UserModel({
    this.id = '',
    required this.name,
    required this.phone,
    required this.packageType,
    this.expiryDate,
    this.deviceId = '',
  });

  final String id;
  final String name;
  final String phone;
  final PackageType packageType;
  final DateTime? expiryDate;
  final String deviceId;

  bool get isPremium => packageType == PackageType.premium;

  /// Premium with a valid (or unset) expiry — false once the sub has ended.
  bool get hasActiveSubscription {
    if (!isPremium) return false;
    if (expiryDate == null) return true;
    return expiryDate!.isAfter(DateTime.now());
  }

  String get packageLabel =>
      hasActiveSubscription ? 'Premium' : 'Bila Malipo';

  /// Human-readable remaining subscription time (Swahili).
  String get remainingLabel {
    if (expiryDate == null) {
      return hasActiveSubscription ? 'Haijawekwa' : 'Haijawekwa';
    }
    final diff = expiryDate!.difference(DateTime.now());
    if (diff.isNegative) return 'Imeisha';
    if (diff.inDays >= 1) return '${diff.inDays} siku';
    if (diff.inHours >= 1) return '${diff.inHours} saa';
    final mins = diff.inMinutes;
    return mins <= 0 ? 'Chini ya dakika' : '$mins dakika';
  }

  /// Date plus remaining time for the Mtumiaji screen.
  String get expiryLabel {
    if (expiryDate == null) {
      return hasActiveSubscription ? 'Haijawekwa' : 'Haijawekwa';
    }
    final date =
        '${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}';
    return '$date · $remainingLabel';
  }

  String get deviceIdLabel {
    if (deviceId.isEmpty) return 'Haijawekwa';
    return deviceId;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Free User',
      phone: json['phone'] as String? ?? '',
      packageType: json['packageType'] == 'premium'
          ? PackageType.premium
          : PackageType.free,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'] as String)
          : null,
      deviceId: (json['deviceId'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'packageType': isPremium ? 'premium' : 'free',
        'expiryDate': expiryDate?.toIso8601String(),
        'deviceId': deviceId,
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    PackageType? packageType,
    DateTime? expiryDate,
    String? deviceId,
    bool clearExpiry = false,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      packageType: packageType ?? this.packageType,
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
      deviceId: deviceId ?? this.deviceId,
    );
  }

  static const defaultUser = UserModel(
    name: 'Free User',
    phone: '',
    packageType: PackageType.free,
  );
}
