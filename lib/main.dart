import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class MacRecorderPage extends StatefulWidget {
  @override
  _MacRecorderPageState createState() => _MacRecorderPageState();
}

class _MacRecorderPageState extends State<MacRecorderPage> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _filePath;

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      String tempDir;

      if (Platform.isAndroid) {
        // Android: /storage/emulated/0/Documents/YourApp
        final directory = Directory('/storage/emulated/0/Documents/MeetingRecorder');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        tempDir = directory.path;
      } else {
        // macOS: 내부 문서 디렉토리
        tempDir = (await getApplicationDocumentsDirectory()).path;
      }

      // 파일 이름은 날짜_시간 형식
      _filePath = '$tempDir/${DateTime.now().toIso8601String()}.wav';

      await _recorder.start(const RecordConfig(), path: _filePath!);

      setState(() {
        _isRecording = true;
      });
    } else {
      print("Permission denied.");
    }
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _uploadRecording() async {
    if (_filePath == null || !File(_filePath!).existsSync()) return;

    var uri = Uri.parse('http://<YOUR_FASTAPI_SERVER>:8000/upload-audio/');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', _filePath!));

    var response = await request.send();
    if (response.statusCode == 200) {
      print("Upload successful!");
    } else {
      print("Upload failed: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("macOS Audio Recorder")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? "Stop Recording" : "Start Recording"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadRecording,
              child: Text("Upload Recording"),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: MacRecorderPage(),
  ));
}
