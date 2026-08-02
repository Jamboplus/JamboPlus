enum PackageType { free, premium }

class UserModel {
  const UserModel({
    this.id = '',
    required this.name,
    required this.phone,
    required this.packageType,
    this.expiryDate,
  });

  final String id;
  final String name;
  final String phone;
  final PackageType packageType;
  final DateTime? expiryDate;

  bool get isPremium => packageType == PackageType.premium;

  /// Premium with a valid (or unset) expiry — false once the sub has ended.
  bool get hasActiveSubscription {
    if (!isPremium) return false;
    if (expiryDate == null) return true;
    return expiryDate!.isAfter(DateTime.now());
  }

  String get packageLabel =>
      hasActiveSubscription ? 'Premium' : 'Bila Malipo';

  String get expiryLabel {
    if (expiryDate == null) return 'Haijawekwa';
    return '${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}';
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'packageType': isPremium ? 'premium' : 'free',
        'expiryDate': expiryDate?.toIso8601String(),
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    PackageType? packageType,
    DateTime? expiryDate,
    bool clearExpiry = false,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      packageType: packageType ?? this.packageType,
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
    );
  }

  static const defaultUser = UserModel(
    name: 'Free User',
    phone: '',
    packageType: PackageType.free,
  );
}
