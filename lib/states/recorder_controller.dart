import 'dart:developer';
import 'dart:io';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecorderController extends GetxController {
  final recorder = AudioRecorder();

  var isRecording = false.obs;
  var uploadStatus = "".obs;
  var filePath = RxnString();
  var amplitude = 0.0.obs; // 🆕 실시간 입력 음량

  final urlTextController = TextEditingController();

  static const String _urlKey = 'server_url'; // 저장용 키

  @override
  void onInit() {
    super.onInit();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_urlKey);
    if (savedUrl != null) {
      urlTextController.text = savedUrl;
    }
  }

  Future<void> _saveUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, urlTextController.text.trim());
  }

  String generateTimestampedFilename({String extension = "wav"}) {
    final now = DateTime.now();
    final formatted = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_"
        "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
    return "$formatted.$extension";
  }

  Future<void> startRecording() async {
    try {
      bool hasPermission = await recorder.hasPermission();

      if (!hasPermission) {
        // 추가: permission_handler로 요청
        var micStatus = await Permission.microphone.request();

        if (micStatus != PermissionStatus.granted) {
          uploadStatus.value = "❌ 마이크 권한이 거부되었습니다.";
          Get.snackbar(
            "권한 필요",
            "녹음을 위해 마이크 권한이 필요합니다.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
          );
          log("Microphone permission denied after request.", time: DateTime.now());
          return;
        }
      }

      String tempDir;

      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Documents/MeetingRecorder');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        tempDir = directory.path;
      } else if (Platform.isLinux || Platform.isMacOS) {
        final directory = Directory('${Platform.environment['HOME']}/MeetingRecorder');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        tempDir = directory.path;
      } else {
        tempDir = (await getApplicationDocumentsDirectory()).path;
      }

      filePath.value = '$tempDir/${generateTimestampedFilename()}';

      final config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      );

      await recorder.start(config, path: filePath.value!);

      final isActuallyRecording = await recorder.isRecording();
      if (!isActuallyRecording) {
        uploadStatus.value = "❌ 녹음 시작 실패";
        log("Recording failed to start.", time: DateTime.now());
        return;
      }

      isRecording.value = true;
      uploadStatus.value = "";

      recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
        amplitude.value = amp.current.toDouble();
      });

      log("Recording started.", time: DateTime.now());
    } catch (e) {
      log("Error during recording start: $e", time: DateTime.now());
      uploadStatus.value = "❌ 녹음 시작 오류: $e";
    }
  }

  Future<void> stopRecording() async {
    await recorder.stop();
    isRecording.value = false;
    amplitude.value = 0.0; // 🆕 녹음 종료 시 음량 초기화

    if (filePath.value != null) {
      await _saveUrl();
      await uploadRecording(filePath.value!);
    }
  }

  Future<void> uploadRecording(String path) async {
    // (업로드 로직 생략: 앞서 작성한 것과 동일)
  }

  @override
  void onClose() {
    urlTextController.dispose();
    super.onClose();
  }
}