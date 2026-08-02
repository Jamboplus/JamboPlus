class CarouselModel {
  const CarouselModel({
    required this.id,
    required this.image,
    required this.title,
  });

  final String id;
  final String image;
  final String title;

  factory CarouselModel.fromJson(Map<String, dynamic> json) {
    return CarouselModel(
      id: json['id'] as String,
      image: json['image'] as String,
      title: json['title'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'image': image,
        'title': title,
      };
}
