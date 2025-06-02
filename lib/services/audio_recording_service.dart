import 'package:record/record.dart';
import '../interfaces/recording_interfaces.dart';
import 'platform_storage_service.dart';
import 'dart:async';

class AudioRecordingService implements IRecordingControl, IAmplitudeMonitor {
  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _amplitudeTimer;
  String? _currentRecordingPath;
  Function(double)? _amplitudeCallback;

  @override
  Future<String?> startRecording([String? customPath]) async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        throw Exception('녹음 권한이 없습니다');
      }

      String recordingPath;
      if (customPath != null) {
        recordingPath = customPath;
      } else {
        // 플랫폼별 최적 경로 사용
        final storagePath = await PlatformStorageService.getOptimalStoragePath();
        final dateBasedPath = await PlatformStorageService.createDateBasedDirectory(storagePath);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'recording_$timestamp.m4a';
        recordingPath = '$dateBasedPath/$fileName';
      }

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: recordingPath,
      );

      _currentRecordingPath = recordingPath;
      
      // 저장 경로 정보 출력
      final storageInfo = await PlatformStorageService.getStorageInfo();
      print('🎤 녹음 시작');
      print('📁 플랫폼: ${storageInfo['platform']}');
      print('📁 저장 경로: $recordingPath');
      print('📁 설명: ${storageInfo['description']}');
      
      return recordingPath;
    } catch (e) {
      print('❌ 녹음 시작 실패: $e');
      rethrow;
    }
  }

  @override
  Future<String?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      final recordedPath = _currentRecordingPath;
      _currentRecordingPath = null;
      
      if (path != null && recordedPath != null) {
        print('🎤 녹음 완료: $recordedPath');
        return recordedPath;
      }
      
      return path;
    } catch (e) {
      print('❌ 녹음 중지 실패: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }

  @override
  void startAmplitudeMonitoring(Function(double) onAmplitudeChanged) {
    _amplitudeCallback = onAmplitudeChanged;
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      try {
        final amplitude = await _audioRecorder.getAmplitude();
        _amplitudeCallback?.call(amplitude.current);
      } catch (e) {
        print('⚠️ 진폭 모니터링 오류: $e');
      }
    });
  }

  @override
  void stopAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _amplitudeCallback?.call(0.0);
    _amplitudeCallback = null;
  }

  @override
  void dispose() {
    stopAmplitudeMonitoring();
    _audioRecorder.dispose();
  }
}