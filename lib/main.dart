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

  bool _isUploading = false;
  String _uploadStatus = ""; // 메시지 상태

  final TextEditingController _URLTextController = TextEditingController();

  String generateTimestampedFilename({String extension = "wav"}) {
    final now = DateTime.now();
    final formatted = "${now.year}"
        "${now.month.toString().padLeft(2, '0')}"
        "${now.day.toString().padLeft(2, '0')}_"
        "${now.hour.toString().padLeft(2, '0')}"
        "${now.minute.toString().padLeft(2, '0')}"
        "${now.second.toString().padLeft(2, '0')}";

    return "$formatted.$extension";
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      String tempDir;

      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Documents/MeetingRecorder');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        tempDir = directory.path;
      } else if (Platform.isLinux) {
        final directory = Directory('${Platform.environment['HOME']}/MeetingRecorder');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        tempDir = directory.path;
      } else {
        tempDir = (await getApplicationDocumentsDirectory()).path;
      }

      _filePath = '$tempDir/${generateTimestampedFilename()}';

      await _recorder.start(const RecordConfig(), path: _filePath!);

      setState(() {
        _isRecording = true;
        _uploadStatus = "";
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

    setState(() {
      _isUploading = true;
      _uploadStatus = "업로드 중...";
    });

    try {
      var uri = Uri.parse('http://${_URLTextController.text}');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', _filePath!));

      var response = await request.send();

      if (response.statusCode == 200) {
        setState(() {
          _uploadStatus = "✅ 업로드 성공!";
        });
      } else {
        setState(() {
          _uploadStatus = "❌ 업로드 실패 (코드: ${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _uploadStatus = "❌ 업로드 중 오류 발생: $e";
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("macOS Audio Recorder")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _URLTextController,
                decoration: InputDecoration(
                  labelText: "FastAPI 서버 주소 (예: localhost:8000/upload-audio/)",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                child: Text(_isRecording ? "🛑 녹음 중지" : "🎙️ 녹음 시작"),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isUploading ? null : _uploadRecording,
                child: Text("📤 업로드"),
              ),
              SizedBox(height: 20),
              if (_isUploading) CircularProgressIndicator(),
              if (_uploadStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _uploadStatus,
                    style: TextStyle(
                      fontSize: 16,
                      color: _uploadStatus.contains("성공") ? Colors.green : Colors.redAccent,
                    ),
                  ),
                ),
            ],
          ),
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