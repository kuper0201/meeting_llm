import 'dart:developer';
import 'dart:io';
import 'package:get/get.dart';
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
    if (await recorder.hasPermission()) {
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

      log("Save Dir: $tempDir", time: DateTime.now());

      filePath.value = '$tempDir/${generateTimestampedFilename()}';

      await recorder.start(const RecordConfig(), path: filePath.value!);

      isRecording.value = true;
      uploadStatus.value = "";

      // 🆕 실시간 amplitude 감지 시작
      recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
        amplitude.value = amp.current.toDouble(); // -160 ~ 0 dB
      });
    } else {
      print("Permission denied.");
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