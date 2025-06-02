import 'dart:io';

import 'package:record_meet/services/http_upload_strategy.dart';

import '../interfaces/recording_interfaces.dart';
import '../services/local_file_service.dart';
import '../interfaces/storage_repository.dart';
import '../services/file_upload_service.dart';
import '../services/platform_storage_service.dart';

// 비즈니스 로직을 담당하는 Use Case
class RecordingUseCase {
  final IRecordingControl _recordingControl;
  final IAmplitudeMonitor _amplitudeMonitor;
  final LocalFileService _localFileService;
  final IStorageRepository<Map<String, dynamic>> _storageRepository;
  final FileUploadService _uploadService;

  RecordingUseCase(
    this._recordingControl,
    this._amplitudeMonitor,
    this._localFileService,
    this._storageRepository,
    this._uploadService,
  );

  Future<String> startRecording(Function(double) onAmplitudeChanged) async {
    final recordingPath = await _recordingControl.startRecording();
    if (recordingPath != null) {
      _amplitudeMonitor.startAmplitudeMonitoring(onAmplitudeChanged);
      return recordingPath;
    } else {
      throw Exception('녹음을 시작할 수 없습니다');
    }
  }

  Future<void> stopRecordingAndSave() async {
    _amplitudeMonitor.stopAmplitudeMonitoring();
    final path = await _recordingControl.stopRecording();
    
    if (path != null) {
      await _saveRecordingInfo(path);
    } else {
      throw Exception('녹음을 중지할 수 없습니다');
    }
  }

  Future<void> openStorageInExplorer() async {
    try {
      await PlatformStorageService.openInSystemExplorer();
    } catch (e) {
      throw Exception('저장소를 열 수 없습니다: $e');
    }
  }

  Future<void> _saveRecordingInfo(String filePath) async {
    final recordingInfo = await _createRecordingInfo(filePath);
    final key = _generateStorageKey(recordingInfo);
    await _storageRepository.save(key, recordingInfo);
    await _localFileService.saveRecordingInfo(recordingInfo);
  }

  Future<void> _attemptUpload(String filePath) async {
    final metadata = <String, String>{
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'audio_recording',
    };
    
    await _uploadService.uploadFile(filePath, metadata);
  }

  Future<Map<String, dynamic>> _createRecordingInfo(String filePath) async {
    final file = File(filePath);
    final fileSize = await file.length();
    final fileName = filePath.split('/').last;
    final timestamp = DateTime.now().toIso8601String();
    
    // 플랫폼별 저장 경로 정보 추가
    final storageInfo = await PlatformStorageService.getStorageInfo();
    
    return {
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
      'timestamp': timestamp,
      'uploaded': false,
      'uploadAttempts': 0,
      'platform': Platform.operatingSystem,
      'storageType': storageInfo['description'],
      'userVisible': storageInfo['userVisible'] == 'true',
    };
  }

  // RecordingUseCase에 추가해야 할 메서드들

  Future<List<Map<String, dynamic>>> loadLocalRecordings() async {
    return await _localFileService.loadLocalRecordings();
  }

  Future<bool> uploadFile(Map<String, dynamic> recordingInfo, String serverUrl) async {
    try {
      // 업로드 전략 설정
      _uploadService.setUploadStrategy(HttpUploadStrategy(serverUrl));
      
      final metadata = <String, String>{
        'timestamp': recordingInfo['timestamp'] ?? DateTime.now().toIso8601String(),
        'type': 'audio_recording',
        'originalFileName': recordingInfo['fileName'] ?? '',
        'platform': Platform.operatingSystem,
      };
      
      final success = await _uploadService.uploadFile(recordingInfo['filePath'], metadata);
      
      // 업로드 상태 업데이트
      await _updateUploadStatus(recordingInfo, success);
      
      return success;
    } catch (e) {
      await _updateUploadStatus(recordingInfo, false, e.toString());
      rethrow;
    }
  }

  Future<void> deleteLocalFile(Map<String, dynamic> recordingInfo) async {
    await _localFileService.deleteLocalFile(recordingInfo['filePath']);
    
    // 저장소에서도 제거
    final key = _generateStorageKey(recordingInfo);
    await _storageRepository.delete(key);
  }

  Future<void> _updateUploadStatus(Map<String, dynamic> recordingInfo, bool success, [String? error]) async {
    if (success) {
      recordingInfo['uploaded'] = true;
      recordingInfo['uploadedAt'] = DateTime.now().toIso8601String();
    } else {
      recordingInfo['uploadAttempts'] = (recordingInfo['uploadAttempts'] ?? 0) + 1;
      if (error != null) {
        recordingInfo['lastUploadError'] = error;
      }
    }
    
    // 저장소에 업데이트된 정보 저장
    final key = _generateStorageKey(recordingInfo);
    await _storageRepository.save(key, recordingInfo);
    await _localFileService.updateRecordingInfo(recordingInfo);
  }

  String _generateStorageKey(Map<String, dynamic> recordingInfo) {
    final timestamp = recordingInfo['timestamp'] ?? DateTime.now().toIso8601String();
    return 'recording_${timestamp.replaceAll(RegExp(r'[^\w]'), '_')}';
  }

  /// 현재 저장 경로 정보 반환 - Controller에서 요구하는 형식으로 반환
  Future<Map<String, String>> getStorageInfo() async {
    try {
      // PlatformStorageService에서 저장 경로 정보 가져오기
      final storageInfo = await PlatformStorageService.getStorageInfo();
      
      // Controller에서 기대하는 형식으로 변환
      return {
        'platform': storageInfo['platform'] ?? Platform.operatingSystem,
        'optimalPath': storageInfo['optimalPath'] ?? '',
        'description': storageInfo['description'] ?? 'Unknown storage',
        'userVisible': storageInfo['userVisible'] ?? 'false',
      };
    } catch (e) {
      print('❌ 저장 경로 정보 로드 실패: $e');
      // 오류 발생 시 기본값 반환
      return {
        'platform': Platform.operatingSystem,
        'optimalPath': 'Unknown',
        'description': '저장 경로 정보를 불러올 수 없습니다',
        'userVisible': 'false',
      };
    }
  }
}