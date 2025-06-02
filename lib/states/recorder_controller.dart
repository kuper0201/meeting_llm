import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../use_cases/recording_use_case.dart';
import '../use_cases/playback_use_case.dart';
import '../use_cases/transcription_use_case.dart';
import '../services/playback_state_service.dart';
import '../services/settings_service.dart';
import 'dart:async';
import 'dart:io';

class RecorderController extends GetxController {
  final RecordingUseCase _recordingUseCase;
  final PlaybackUseCase _playbackUseCase;
  final TranscriptionUseCase _transcriptionUseCase;
  final PlaybackStateService _playbackStateService;
  final SettingsService _settingsService;

  final TextEditingController urlTextController = TextEditingController();
  
  // 녹음 관련 상태
  var isRecording = false.obs;
  var amplitude = 0.0.obs;
  
  // 업로드 관련 상태
  var uploadStatus = ''.obs;
  var isUploadingFile = false.obs;
  var currentUploadingFile = ''.obs;
  
  // 로컬 파일 관련 상태
  var localRecordings = <Map<String, dynamic>>[].obs;
  var isLoadingLocalFiles = false.obs;
  
  // 전사 관련 상태
  var transcriptions = <Map<String, dynamic>>[].obs;
  var isLoadingTranscriptions = false.obs;
  var transcriptionError = ''.obs;
  var isDeletingTranscription = false.obs;
  
  // 저장 경로 정보
  var storageInfo = <String, String>{}.obs;

  RecorderController(
    this._recordingUseCase,
    this._playbackUseCase,
    this._transcriptionUseCase,
    this._playbackStateService,
    this._settingsService,
  );

  @override
  void onInit() {
    super.onInit();
    _loadServerUrl();
    loadLocalRecordings();
    _loadStorageInfo();
  }

  @override
  void onClose() {
    urlTextController.dispose();
    super.onClose();
  }

  // ==================== 저장 경로 관련 ====================

  /// 저장 경로 정보 로드
  Future<void> _loadStorageInfo() async {
    try {
      final info = await _recordingUseCase.getStorageInfo();
      storageInfo.value = info;
      
      print('📁 저장 경로 정보 로드됨:');
      print('  - 플랫폼: ${info['platform']}');
      print('  - 경로: ${info['optimalPath']}');
      print('  - 설명: ${info['description']}');
      print('  - 사용자 접근 가능: ${info['userVisible']}');
    } catch (e) {
      print('❌ 저장 경로 정보 로드 실패: $e');
    }
  }

  /// 저장 폴더를 시스템 파일 탐색기에서 열기
  Future<void> openStorageFolder() async {
    try {
      await _recordingUseCase.openStorageInExplorer();
      
      if (Platform.isMacOS) {
        uploadStatus.value = 'Finder에서 저장 폴더를 열었습니다';
      } else if (Platform.isWindows) {
        uploadStatus.value = '탐색기에서 저장 폴더를 열었습니다';
      } else if (Platform.isLinux) {
        uploadStatus.value = '파일 관리자에서 저장 폴더를 열었습니다';
      } else {
        uploadStatus.value = '저장 폴더 열기를 시도했습니다';
      }
      
      _clearStatusAfterDelay();
    } catch (e) {
      print('❌ 저장 폴더 열기 실패: $e');
      uploadStatus.value = '저장 폴더 열기에 실패했습니다';
      _clearStatusAfterDelay();
    }

  }
  /// 저장 경로 정보 텍스트 반환
  String getStorageInfoText() {
    if (storageInfo.isEmpty) return '저장 경로 정보를 불러오는 중...';
    
    final platform = storageInfo['platform'] ?? 'Unknown';
    final description = storageInfo['description'] ?? 'Unknown';
    final userVisible = storageInfo['userVisible'] == 'true';
    
    String visibilityText = userVisible ? '사용자 접근 가능' : '앱 전용 폴더';
    
    return '$platform - $description\n($visibilityText)';
  }

  // ==================== 녹음 관련 ====================

  Future<void> startRecording() async {
    try {
      await _recordingUseCase.startRecording((amplitude) {
        this.amplitude.value = amplitude;
      });
      
      isRecording.value = true;
      uploadStatus.value = '';
      
      print('🎤 녹음 시작됨');
    } catch (e) {
      print('❌ 녹음 시작 실패: $e');
      uploadStatus.value = '녹음 시작에 실패했습니다: $e';
      _clearStatusAfterDelay();
    }
  }

  Future<void> stopRecording() async {
    try {
      await _recordingUseCase.stopRecordingAndSave();
      
      isRecording.value = false;
      amplitude.value = 0.0;
      
      // 로컬 녹음 목록 새로고침
      await loadLocalRecordings();
      
      uploadStatus.value = '녹음이 완료되어 저장되었습니다';
      print('🎤 녹음 완료 및 저장됨');
      
      // 자동 업로드 시도
      if (urlTextController.text.trim().isNotEmpty && localRecordings.isNotEmpty) {
        final latestRecording = localRecordings.first;
        await _attemptUpload(latestRecording);
      }
      
      _clearStatusAfterDelay();
    } catch (e) {
      print('❌ 녹음 중지 실패: $e');
      uploadStatus.value = '녹음 중지에 실패했습니다: $e';
      isRecording.value = false;
      amplitude.value = 0.0;
      _clearStatusAfterDelay();
    }
  }

  // ==================== 로컬 파일 관리 ====================

  Future<void> loadLocalRecordings() async {
    try {
      isLoadingLocalFiles.value = true;
      final recordings = await _recordingUseCase.loadLocalRecordings();
      localRecordings.value = recordings;
      
      print('📁 로컬 녹음 파일 ${recordings.length}개 로드됨');
    } catch (e) {
      print('❌ 로컬 녹음 파일 로드 실패: $e');
    } finally {
      isLoadingLocalFiles.value = false;
    }
  }

  Future<void> _attemptUpload(Map<String, dynamic> recordingInfo) async {
    final serverUrl = urlTextController.text.trim();
    if (serverUrl.isEmpty) {
      print('⚠️ 서버 주소가 없어 업로드를 건너뜁니다');
      return;
    }
    
    await uploadLocalFile(recordingInfo);
  }

  Future<void> uploadLocalFile(Map<String, dynamic> recordingInfo) async {
    try {
      isUploadingFile.value = true;
      currentUploadingFile.value = recordingInfo['fileName'];
      
      await _settingsService.saveServerUrl(urlTextController.text.trim());
      
      final serverUrl = urlTextController.text.trim();
      final success = await _recordingUseCase.uploadFile(recordingInfo, serverUrl);
      
      if (success) {
        uploadStatus.value = '업로드 성공: ${recordingInfo['fileName']}';
        print('✅ 업로드 성공: ${recordingInfo['fileName']}');
        
        // 로컬 목록 새로고침
        await loadLocalRecordings();
        
        // transcription 목록 새로고침
        await fetchTranscriptions();
      } else {
        uploadStatus.value = '업로드 실패: ${recordingInfo['fileName']}';
        print('❌ 업로드 실패: ${recordingInfo['fileName']}');
      }
    } catch (e) {
      print('💥 업로드 중 예외: $e');
      uploadStatus.value = '업로드 오류: ${recordingInfo['fileName']}';
    } finally {
      isUploadingFile.value = false;
      currentUploadingFile.value = '';
      _clearStatusAfterDelay();
    }
  }

  Future<void> deleteLocalFile(Map<String, dynamic> recordingInfo) async {
    try {
      await _recordingUseCase.deleteLocalFile(recordingInfo);
      await loadLocalRecordings();
      
      uploadStatus.value = '로컬 파일이 삭제되었습니다';
      print('🗑️ 로컬 파일 삭제됨: ${recordingInfo['fileName']}');
      _clearStatusAfterDelay();
    } catch (e) {
      print('❌ 로컬 파일 삭제 실패: $e');
      uploadStatus.value = '파일 삭제에 실패했습니다';
      _clearStatusAfterDelay();
    }
  }

  Future<void> uploadAllPendingFiles() async {
    final pendingFiles = localRecordings.where((item) => 
        item['uploaded'] != true).toList();
    
    if (pendingFiles.isEmpty) {
      uploadStatus.value = '업로드할 파일이 없습니다';
      _clearStatusAfterDelay();
      return;
    }
    
    uploadStatus.value = '${pendingFiles.length}개 파일 업로드 중...';
    
    for (var recordingInfo in pendingFiles) {
      await uploadLocalFile(recordingInfo);
      // 각 파일 업로드 사이에 잠시 대기
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  // ==================== 전사 관리 ====================

  Future<void> fetchTranscriptions() async {
    try {
      isLoadingTranscriptions.value = true;
      transcriptionError.value = '';
      
      final serverUrl = urlTextController.text.trim();
      if (serverUrl.isEmpty) {
        transcriptionError.value = '서버 주소를 입력해주세요';
        return;
      }
      
      final transcriptionList = await _transcriptionUseCase.fetchTranscriptions(serverUrl);
      transcriptions.value = transcriptionList;
      
      print('📝 전사 목록 ${transcriptionList.length}개 로드됨');
    } catch (e) {
      print('❌ 전사 목록 로드 실패: $e');
      transcriptionError.value = '전사 목록 로드 실패: $e';
    } finally {
      isLoadingTranscriptions.value = false;
    }
  }

  Future<void> deleteTranscription(int transcriptionId) async {
    try {
      isDeletingTranscription.value = true;
      transcriptionError.value = '';
      
      final serverUrl = urlTextController.text.trim();
      if (serverUrl.isEmpty) {
        transcriptionError.value = '서버 주소를 입력해주세요';
        return;
      }
      
      await _transcriptionUseCase.deleteTranscription(serverUrl, transcriptionId);
      
      // 로컬 목록에서 해당 항목 제거
      transcriptions.removeWhere((item) => item['id'] == transcriptionId);
      uploadStatus.value = 'Transcription이 성공적으로 삭제되었습니다';
      print('✅ Transcription 삭제 성공: ID $transcriptionId');
      _clearStatusAfterDelay();
    } catch (e) {
      print('❌ Transcription 삭제 실패: $e');
      transcriptionError.value = '삭제 실패: $e';
      uploadStatus.value = '삭제에 실패했습니다';
      _clearStatusAfterDelay();
    } finally {
      isDeletingTranscription.value = false;
    }
  }

  // ==================== 재생 관련 ====================

  Future<void> playAudio(String filePath, String fileName) async {
    try {
      await _playbackUseCase.playAudio(filePath, fileName);
      print('🔊 재생 시작: $fileName');
    } catch (e) {
      print('❌ 재생 실패: $e');
      uploadStatus.value = '재생에 실패했습니다: $e';
      _clearStatusAfterDelay();
    }
  }

  Future<void> pauseAudio() async {
    try {
      await _playbackUseCase.pauseAudio();
      print('⏸️ 재생 일시정지');
    } catch (e) {
      print('❌ 일시정지 실패: $e');
    }
  }

  Future<void> stopAudio() async {
    try {
      await _playbackUseCase.stopAudio();
      print('⏹️ 재생 중지');
    } catch (e) {
      print('❌ 재생 중지 실패: $e');
    }
  }

  Future<void> seekAudio(double progress) async {
    try {
      await _playbackUseCase.seekAudio(progress);
    } catch (e) {
      print('❌ 시크 실패: $e');
    }
  }

  // ==================== 설정 관리 ====================

  Future<void> _loadServerUrl() async {
    try {
      final savedUrl = await _settingsService.loadServerUrl();
      urlTextController.text = savedUrl;
    } catch (e) {
      print('❌ 서버 URL 로드 실패: $e');
    }
  }

  Future<void> saveServerUrl() async {
    try {
      await _settingsService.saveServerUrl(urlTextController.text.trim());
    } catch (e) {
      print('❌ 서버 URL 저장 실패: $e');
    }
  }

  Future<void> testServerConnection() async {
    try {
      final serverUrl = urlTextController.text.trim();
      if (serverUrl.isEmpty) {
        uploadStatus.value = '서버 주소를 입력해주세요';
        _clearStatusAfterDelay();
        return;
      }

      uploadStatus.value = '서버 연결 테스트 중...';
      
      // 간단한 연결 테스트 (transcriptions 엔드포인트 호출)
      await _transcriptionUseCase.fetchTranscriptions(serverUrl);
      
      uploadStatus.value = '서버 연결 성공!';
      print('✅ 서버 연결 테스트 성공');
    } catch (e) {
      print('❌ 서버 연결 테스트 실패: $e');
      uploadStatus.value = '서버 연결 실패: $e';
    } finally {
      _clearStatusAfterDelay();
    }
  }

  // ==================== UI 헬퍼 메서드 ====================

  /// 삭제 확인 다이얼로그
  Future<bool> showDeleteConfirmDialog(String filename) async {
    return await Get.dialog<bool>(
      AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('정말로 "$filename"을(를) 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// 녹음 정보 텍스트 생성
  String getRecordingInfoText(Map<String, dynamic> recording) {
    final fileSize = formatFileSize(recording['fileSize'] ?? 0);
    final timestamp = recording['timestamp'] ?? '';
    final uploaded = recording['uploaded'] == true;
    final platform = recording['platform'] ?? 'Unknown';
    final storageType = recording['storageType'] ?? 'Unknown';
    
    String timeText = '';
    if (timestamp.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(timestamp);
        timeText = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        timeText = timestamp;
      }
    }
    
    String statusText = uploaded ? '업로드됨' : '로컬 저장';
    
    return '$fileSize • $timeText\n$platform • $storageType • $statusText';
  }

  /// 업로드 상태 아이콘
  IconData getUploadStatusIcon(Map<String, dynamic> recording) {
    final uploaded = recording['uploaded'] == true;
    final uploadAttempts = recording['uploadAttempts'] ?? 0;
    
    if (uploaded) {
      return Icons.cloud_done;
    } else if (uploadAttempts > 0) {
      return Icons.cloud_off;
    } else {
      return Icons.cloud_upload;
    }
  }

  /// 업로드 상태 색상
  Color getUploadStatusColor(Map<String, dynamic> recording) {
    final uploaded = recording['uploaded'] == true;
    final uploadAttempts = recording['uploadAttempts'] ?? 0;
    
    if (uploaded) {
      return Colors.green;
    } else if (uploadAttempts > 0) {
      return Colors.red;
    } else {
      return Colors.blue;
    }
  }

  /// 파일 크기 포맷팅
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 재생 시간 포맷팅
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// 상태 메시지 자동 초기화
  void _clearStatusAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      uploadStatus.value = '';
    });
  }

  // ==================== 재생 상태 접근자 ====================

  bool get isPlaying => _playbackStateService.isPlaying.value;
  String get currentPlayingFile => _playbackStateService.currentPlayingFile.value;
  Duration get playbackPosition => _playbackStateService.playbackPosition.value;
  Duration get playbackDuration => _playbackStateService.playbackDuration.value;
  double get playbackProgress => _playbackStateService.playbackProgress;
}