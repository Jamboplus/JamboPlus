class PricingPlanModel {
  const PricingPlanModel({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.price,
    required this.originalPrice,
  });

  final String id;
  final String name;
  final int durationDays;
  final double price;
  final double originalPrice;

  factory PricingPlanModel.fromJson(Map<String, dynamic> json) {
    return PricingPlanModel(
      id: json['id'] as String,
      name: json['name'] as String,
      durationDays: (json['durationDays'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ??
          (json['price'] as num).toDouble(),
    );
  }
}
