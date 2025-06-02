import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

// 순수한 오디오 재생 기능만 담당
class AudioPlaybackService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Future<void> play(String filePath) async {
    await _audioPlayer.play(DeviceFileSource(filePath));
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Stream<Duration> get onPositionChanged => _audioPlayer.onPositionChanged;
  Stream<Duration> get onDurationChanged => _audioPlayer.onDurationChanged;
  Stream<PlayerState> get onPlayerStateChanged => _audioPlayer.onPlayerStateChanged;

  void dispose() {
    _audioPlayer.dispose();
  }
}