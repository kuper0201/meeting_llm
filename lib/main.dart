import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MaterialApp(home: VoiceRecorder()));
}

class VoiceRecorder extends StatefulWidget {
  @override
  _VoiceRecorderState createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final recorder = FlutterSoundRecorder();
  bool isRecording = false;
  String? audioPath;

  @override
  void initState() {
    super.initState();
    initRecorder();
  }

  Future<void> initRecorder() async {
    await Permission.microphone.request();
    await recorder.openRecorder();
  }

  Future<void> startRecording() async {
    // final dir = await getApplicationDocumentsDirectory();
    final filePath = '/home/kuper0201/voice.aac';
    final perm = await Permission.microphone.request();
    print(perm);
    await recorder.openRecorder();
    await recorder.startRecorder(toFile: filePath, codec: Codec.aacADTS);
    setState(() {
      isRecording = true;
      audioPath = filePath;
    });
  }

  Future<void> stopRecording() async {
    await recorder.stopRecorder();
    setState(() {
      isRecording = false;
    });
  }

  Future<void> uploadRecording() async {
    if (audioPath == null) return;
    var uri = Uri.parse('http://<your-fastapi-url>/upload-audio');
    var request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', audioPath!));

    var response = await request.send();
    if (response.statusCode == 200) {
      print('Upload success');
    } else {
      print('Upload failed: ${response.statusCode}');
    }
  }

  @override
  void dispose() {
    recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('음성 녹음기')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isRecording ? stopRecording : startRecording,
              child: Text(isRecording ? '녹음 중지' : '녹음 시작'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: uploadRecording,
              child: Text('서버로 업로드'),
            ),
          ],
        ),
      ),
    );
  }
}
