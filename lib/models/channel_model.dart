class ChannelModel {
  const ChannelModel({
    required this.id,
    required this.name,
    required this.image,
    required this.category,
    required this.description,
    required this.isPremium,
    required this.streamUrl,
    this.isLive = false,
    this.playerEngine = 'exoplayer',
    this.drmType = 'none',
    this.drmLicenseUrl = '',
    this.drmClearKey = '',
  });

  final String id;
  final String name;
  final String image;
  final String category;
  final String description;
  final bool isPremium;
  final String streamUrl;
  final bool isLive;
  final String playerEngine;
  final String drmType;
  final String drmLicenseUrl;
  final String drmClearKey;

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: json['id'] as String,
      name: json['name'] as String,
      image: json['image'] as String,
      category: json['category'] as String,
      description: json['description'] as String? ?? '',
      isPremium: json['isPremium'] as bool? ?? false,
      streamUrl: json['streamUrl'] as String? ?? '',
      isLive: json['isLive'] as bool? ?? false,
      playerEngine: json['playerEngine'] as String? ?? 'exoplayer',
      drmType: json['drmType'] as String? ?? 'none',
      drmLicenseUrl: json['drmLicenseUrl'] as String? ?? '',
      drmClearKey: json['drmClearKey'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'category': category,
        'description': description,
        'isPremium': isPremium,
        'streamUrl': streamUrl,
        'isLive': isLive,
        'playerEngine': playerEngine,
        'drmType': drmType,
        'drmLicenseUrl': drmLicenseUrl,
        'drmClearKey': drmClearKey,
      };

  ChannelModel copyWith({
    String? id,
    String? name,
    String? image,
    String? category,
    String? description,
    bool? isPremium,
    String? streamUrl,
    bool? isLive,
    String? playerEngine,
    String? drmType,
    String? drmLicenseUrl,
    String? drmClearKey,
  }) {
    return ChannelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      image: image ?? this.image,
      category: category ?? this.category,
      description: description ?? this.description,
      isPremium: isPremium ?? this.isPremium,
      streamUrl: streamUrl ?? this.streamUrl,
      isLive: isLive ?? this.isLive,
      playerEngine: playerEngine ?? this.playerEngine,
      drmType: drmType ?? this.drmType,
      drmLicenseUrl: drmLicenseUrl ?? this.drmLicenseUrl,
      drmClearKey: drmClearKey ?? this.drmClearKey,
    );
  }
}
