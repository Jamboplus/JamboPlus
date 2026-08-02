class AppConfigModel {
  const AppConfigModel({
    required this.playerEngine,
    required this.drmType,
    required this.streamOrigin,
    required this.streamReferer,
    required this.userAgent,
    required this.tokenRefreshUrl,
    required this.streamUserId,
    required this.appApiKey,
    required this.maintenanceMode,
  });

  final String playerEngine;
  final String drmType;
  final String streamOrigin;
  final String streamReferer;
  final String userAgent;
  final String tokenRefreshUrl;
  final String streamUserId;
  final String appApiKey;
  final bool maintenanceMode;

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    return AppConfigModel(
      playerEngine: json['playerEngine'] as String? ?? 'exoplayer',
      drmType: json['drmType'] as String? ?? 'none',
      streamOrigin: json['streamOrigin'] as String? ?? '',
      streamReferer: json['streamReferer'] as String? ?? '',
      userAgent: json['userAgent'] as String? ?? '',
      tokenRefreshUrl: json['tokenRefreshUrl'] as String? ?? '',
      streamUserId: json['streamUserId'] as String? ?? '',
      appApiKey: json['appApiKey'] as String? ?? '',
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
    );
  }
}

class BootstrapModel {
  const BootstrapModel({
    required this.config,
    required this.maintenanceMode,
  });

  final AppConfigModel config;
  final bool maintenanceMode;

  factory BootstrapModel.fromJson(Map<String, dynamic> json) {
    return BootstrapModel(
      config: AppConfigModel.fromJson(
        json['config'] as Map<String, dynamic>,
      ),
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
    );
  }
}
