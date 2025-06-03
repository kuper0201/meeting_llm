import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:record_meet/interfaces/storage_repository.dart';
import 'package:record_meet/services/local_file_service.dart';
import 'package:record_meet/services/platform_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../use_cases/recording_use_case.dart';
import '../use_cases/playback_use_case.dart';
import '../use_cases/transcription_use_case.dart';
import '../services/playback_state_service.dart';
import '../services/settings_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;

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

  // ==================== 수동 업로드 ======================
  Future<void> _saveRecordingInfo(String filePath) async {
    final recordingInfo = await _createFileInfo(filePath);
    final key = _generateStorageKey(recordingInfo);
    await Get.find<IStorageRepository<Map<String, dynamic>>>().save(key, recordingInfo);
    await Get.find<LocalFileService>().saveRecordingInfo(recordingInfo);
  }

  String _generateStorageKey(Map<String, dynamic> recordingInfo) {
    final timestamp = recordingInfo['timestamp'] ?? DateTime.now().toIso8601String();
    return 'recording_${timestamp.replaceAll(RegExp(r'[^\w]'), '_')}';
  }

  Future<Map<String, dynamic>> _createFileInfo(String filePath) async {
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

  /// 외부 음성 파일 가져오기
  Future<void> importExternalAudioFile() async {
    try {
      // 파일 선택기 열기
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        final fileName = result.files.single.name;
        
        // 파일 크기 체크 (예: 100MB 제한)
        final fileSize = await pickedFile.length();
        if (fileSize > 100 * 1024 * 1024) {
          Get.snackbar(
            '파일 크기 초과',
            '파일 크기가 100MB를 초과합니다.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
          );
          return;
        }

        // 로딩 상태 표시
        uploadStatus.value = '파일을 가져오는 중...';
        isUploadingFile.value = true;

        // 플랫폼별 최적 저장 경로 가져오기
        final storagePath = await PlatformStorageService.getOptimalStoragePath();
        final recordingsDir = await PlatformStorageService.createDateBasedDirectory(storagePath);
        

        // 파일명 중복 체크 및 처리
        String finalFileName = fileName;
        String baseName = path.basenameWithoutExtension(fileName);
        String extension = path.extension(fileName);
        int counter = 1;

        while (await File('${recordingsDir}/$finalFileName').exists()) {
          finalFileName = '${baseName}_$counter$extension';
          counter++;
        }

        final destinationFile = File('${recordingsDir}/$finalFileName');
        await pickedFile.copy(destinationFile.path);

        // 파일 정보 생성
        final fileStats = await destinationFile.stat();
        final recording = {
          'fileName': finalFileName,
          'filePath': destinationFile.path,
          'fileSize': fileStats.size,
          'timestamp': fileStats.modified.toIso8601String(),
          'uploaded': false,
          'uploadAttempts': 0,
          'platform': Platform.isMacOS ? 'macos' : Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'unknown',
          'storageType': Platform.isMacOS ? 'macOS 사용자 Documents 폴더' : Platform.isIOS ? 'iOS 앱 Documents 폴더' : 'Android 내부 저장소',
          'userVisible': true
        };

        // 로컬 녹음 목록에 추가
        localRecordings.insert(0, recording);
        
        // SharedPreferences에 저장
        await _saveLocalRecordings();

        uploadStatus.value = '파일을 성공적으로 가져왔습니다: $finalFileName';
        
        // 3초 후 상태 메시지 제거
        Timer(const Duration(seconds: 3), () {
          uploadStatus.value = '';
        });

        Get.snackbar(
          '파일 가져오기 완료',
          '$finalFileName 파일을 성공적으로 가져왔습니다.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[100],
          colorText: Colors.green[800],
        );

      }
    } catch (e) {
      uploadStatus.value = '파일 가져오기 실패: $e';
      Get.snackbar(
        '오류',
        '파일을 가져오는 중 오류가 발생했습니다: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
      );
    } finally {
      isUploadingFile.value = false;
    }
  }  /// 오디오 파일의 재생 시간 가져오기 (대략적인 계산)
  Future<String> _getAudioDuration(String filePath) async {
    try {
      // audioplayers를 사용하여 오디오 길이 가져오기
      final audioPlayer = AudioPlayer();
      await audioPlayer.setSourceDeviceFile(filePath);
      
      // 오디오 길이 가져오기 (밀리초)
      Duration? duration = await audioPlayer.getDuration();
      await audioPlayer.dispose();
      
      if (duration != null) {
        return formatDuration(duration);
      }
    } catch (e) {
      print('오디오 길이 가져오기 실패: $e');
    }
    
    // 실패 시 파일 크기 기반 추정 (대략적)
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      // MP3 기준 대략적인 계산 (128kbps 기준)
      final estimatedSeconds = (fileSize / (128 * 1024 / 8)).round();
      final duration = Duration(seconds: estimatedSeconds);
      return formatDuration(duration);
    } catch (e) {
      return '알 수 없음';
    }
  }

  /// 로컬 녹음 목록을 SharedPreferences에 저장
  Future<void> _saveLocalRecordings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordingsString = jsonEncode(localRecordings);
      await prefs.setString('local_recordings', recordingsString);
    } catch (e) {
      print('로컬 녹음 목록 저장 실패: $e');
    }
  }

  /// SharedPreferences에서 로컬 녹음 목록 불러오기
  Future<void> _loadLocalRecordings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordingsJson = prefs.getString('local_recordings') ?? '[]';
      
      localRecordings.clear();
      final recordingsList = jsonDecode(recordingsJson) as List<dynamic>;
      for (final recordingJson in recordingsList) {
        try {
          final recording = jsonDecode(recordingJson) as Map<String, dynamic>;
          // 파일이 실제로 존재하는지 확인
          if (await File(recording['filePath']).exists()) {
            localRecordings.add(recording);
          }
        } catch (e) {
          print('녹음 데이터 파싱 실패: $e');
        }
      }
    } catch (e) {
      print('로컬 녹음 목록 불러오기 실패: $e');
    }
  }

  /// 지원되는 오디오 형식인지 확인
  bool _isSupportedAudioFormat(String fileName) {
    final supportedExtensions = ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'];
    final extension = path.extension(fileName).toLowerCase().replaceAll('.', '');
    return supportedExtensions.contains(extension);
  }

  /// 파일 크기를 읽기 쉬운 형태로 변환
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 다중 파일 가져오기 (선택사항)
  Future<void> importMultipleAudioFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        uploadStatus.value = '${result.files.length}개 파일을 가져오는 중...';
        isUploadingFile.value = true;

        int successCount = 0;
        int failCount = 0;

        for (final file in result.files) {
          if (file.path != null) {
            try {
              await _importSingleFile(File(file.path!), file.name);
              successCount++;
            } catch (e) {
              failCount++;
              print('파일 가져오기 실패: ${file.name}, 오류: $e');
            }
          }
        }

        uploadStatus.value = '가져오기 완료: 성공 $successCount개, 실패 $failCount개';
        
        Timer(const Duration(seconds: 3), () {
          uploadStatus.value = '';
        });

        Get.snackbar(
          '파일 가져오기 완료',
          '총 ${result.files.length}개 파일 중 $successCount개를 성공적으로 가져왔습니다.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: successCount > 0 ? Colors.green[100] : Colors.red[100],
          colorText: successCount > 0 ? Colors.green[800] : Colors.red[800],
        );
      }
    } catch (e) {
      uploadStatus.value = '다중 파일 가져오기 실패: $e';
      Get.snackbar(
        '오류',
        '파일들을 가져오는 중 오류가 발생했습니다: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
      );
    } finally {
      isUploadingFile.value = false;
    }
  }

  /// 단일 파일 가져오기 헬퍼 메서드
  Future<void> _importSingleFile(File sourceFile, String fileName) async {
    final fileSize = await sourceFile.length();
    if (fileSize > 100 * 1024 * 1024) {
      throw Exception('파일 크기가 100MB를 초과합니다');
    }

    final appDir = await PlatformStorageService.getOptimalStoragePath();
    final recordingsDir = Directory('$appDir/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    // 파일명 중복 처리
    String finalFileName = fileName;
    String baseName = path.basenameWithoutExtension(fileName);
    String extension = path.extension(fileName);
    int counter = 1;

    while (await File('${recordingsDir.path}/$finalFileName').exists()) {
      finalFileName = '${baseName}_$counter$extension';
      counter++;
    }

    final destinationFile = File('${recordingsDir.path}/$finalFileName');
    await sourceFile.copy(destinationFile.path);

    final fileStats = await destinationFile.stat();
    final recording = {
      'fileName': finalFileName,
      'filePath': destinationFile.path,
      'fileSize': fileStats.size,
      'createdAt': fileStats.modified.toIso8601String(),
      'uploaded': false,
      'isImported': true,
      'duration': await _getAudioDuration(destinationFile.path),
    };

    localRecordings.insert(0, recording);
    await _saveLocalRecordings();

    _saveRecordingInfo(destinationFile.path);
  }
  // ==================== 재생 상태 접근자 ====================

  bool get isPlaying => _playbackStateService.isPlaying.value;
  String get currentPlayingFile => _playbackStateService.currentPlayingFile.value;
  Duration get playbackPosition => _playbackStateService.playbackPosition.value;
  Duration get playbackDuration => _playbackStateService.playbackDuration.value;
  double get playbackProgress => _playbackStateService.playbackProgress;
}