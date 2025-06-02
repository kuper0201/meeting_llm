import '../services/audio_playback_service.dart';
import '../services/playback_state_service.dart';

class PlaybackUseCase {
  final AudioPlaybackService _playbackService;
  final PlaybackStateService _stateService;

  PlaybackUseCase(this._playbackService, this._stateService);

  Future<void> playAudio(String filePath, String fileName) async {
    // 현재 재생 중인 파일과 같은 파일이면 토글
    if (_stateService.currentPlayingFile.value == fileName) {
      if (_stateService.isPlaying.value) {
        await pauseAudio();
      } else {
        await resumeAudio();
      }
      return;
    }

    // 다른 파일 재생 시 현재 재생 중지 후 새 파일 재생
    await stopAudio();
    await _playbackService.play(filePath);
    _stateService.currentPlayingFile.value = fileName;
  }

  Future<void> pauseAudio() async {
    await _playbackService.pause();
  }

  Future<void> resumeAudio() async {
    await _playbackService.resume();
  }

  Future<void> stopAudio() async {
    await _playbackService.stop();
    _stateService.currentPlayingFile.value = '';
  }

  Future<void> seekAudio(double progress) async {
    if (_stateService.playbackDuration.value.inMilliseconds > 0) {
      final position = Duration(
        milliseconds: (_stateService.playbackDuration.value.inMilliseconds * progress).round(),
      );
      await _playbackService.seek(position);
    }
  }
}