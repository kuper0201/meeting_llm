import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'audio_playback_service.dart';
import 'dart:async';

// 재생 상태 관리만 담당
class PlaybackStateService extends GetxService {
  final AudioPlaybackService _playbackService;
  
  PlaybackStateService(this._playbackService);

  var currentPlayingFile = ''.obs;
  var playbackPosition = Duration.zero.obs;
  var playbackDuration = Duration.zero.obs;
  var isPlaying = false.obs;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void onInit() {
    super.onInit();
    _initializeListeners();
  }

  void _initializeListeners() {
    _positionSubscription = _playbackService.onPositionChanged.listen((position) {
      playbackPosition.value = position;
    });

    _durationSubscription = _playbackService.onDurationChanged.listen((duration) {
      playbackDuration.value = duration;
    });

    _playerStateSubscription = _playbackService.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;
      
      if (state == PlayerState.completed) {
        _resetState();
      }
    });
  }

  void _resetState() {
    currentPlayingFile.value = '';
    playbackPosition.value = Duration.zero;
    playbackDuration.value = Duration.zero;
    isPlaying.value = false;
  }

  double get playbackProgress {
    if (playbackDuration.value.inMilliseconds > 0) {
      return playbackPosition.value.inMilliseconds / playbackDuration.value.inMilliseconds;
    }
    return 0.0;
  }

  @override
  void onClose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    super.onClose();
  }
}