bool get isLinuxPlatform => false;

Future<void> stopSystemVoicePlayback() async {}

Future<void> playVoiceFromTempFile(
  Object player,
  List<int> bytes,
  Object key, {
  required bool Function() isStale,
}) async {}
