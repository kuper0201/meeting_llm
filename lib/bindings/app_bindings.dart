import 'package:get/get.dart';
import 'package:record_meet/repositories/file_storage_repository.dart';
import 'package:record_meet/services/local_file_service.dart';
import 'package:record_meet/services/server_communication_service.dart';
import 'package:record_meet/services/settings_service.dart';
import '../services/audio_recording_service.dart';
import '../services/audio_playback_service.dart';
import '../services/playback_state_service.dart';
import '../services/file_upload_service.dart';
import '../services/http_upload_strategy.dart';
import '../repositories/shared_preferences_repository.dart';
import '../interfaces/storage_repository.dart';
import '../use_cases/recording_use_case.dart';
import '../use_cases/playback_use_case.dart';
import '../use_cases/transcription_use_case.dart';
import '../states/recorder_controller.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    // 기본 서비스들
    Get.lazyPut<AudioRecordingService>(() => AudioRecordingService());
    Get.lazyPut<AudioPlaybackService>(() => AudioPlaybackService());
    
    // 저장소
    Get.lazyPut<IStorageRepository<Map<String, dynamic>>>(
      () => SharedPreferencesRepository()
    );

    // 로컬 저장소
    Get.lazyPut<LocalFileService>(() => LocalFileService());
    
    // 업로드 전략 및 서비스
    Get.lazyPut<FileUploadService>(() => FileUploadService(
      HttpUploadStrategy('') // 기본값, 런타임에 변경됨
    ));
    
    // 상태 서비스
    Get.lazyPut<PlaybackStateService>(() => PlaybackStateService(
      Get.find<AudioPlaybackService>()
    ));

    Get.lazyPut<FileStorageRepository>(() => FileStorageRepository());

    // Use Cases
    Get.lazyPut<RecordingUseCase>(() => RecordingUseCase(
      Get.find<AudioRecordingService>(),
      Get.find<AudioRecordingService>(),
      Get.find<LocalFileService>(),
      Get.find<FileStorageRepository>(),
      Get.find<FileUploadService>(),
    ));
    
    Get.lazyPut<PlaybackUseCase>(() => PlaybackUseCase(
      Get.find<AudioPlaybackService>(),
      Get.find<PlaybackStateService>(),
    ));
    
    Get.lazyPut<TranscriptionUseCase>(() => TranscriptionUseCase(
      ServerCommunicationService(), // 직접 생성 (상태가 없는 서비스)
    ));
    
    Get.lazyPut<SettingsService>(() => SettingsService());
    
    // Controller
    Get.lazyPut<RecorderController>(() => RecorderController(
      Get.find<RecordingUseCase>(),
      Get.find<PlaybackUseCase>(),
      Get.find<TranscriptionUseCase>(),
      Get.find<PlaybackStateService>(),
      Get.find<SettingsService>(),
    ));
  }
}