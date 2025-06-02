// 녹음 기능을 세분화된 인터페이스로 분리
abstract class IRecordingPermission {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
}

abstract class IRecordingControl {
  Future<String?> startRecording();
  Future<String?> stopRecording();
}

abstract class IAmplitudeMonitor {
  void startAmplitudeMonitoring(Function(double) onAmplitudeChanged);
  void stopAmplitudeMonitoring();
}