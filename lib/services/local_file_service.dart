import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

class LocalFileService {
  static const String _localRecordingsKey = 'local_recordings';

  Future<void> saveLocalRecordings(List<Map<String, dynamic>> recordings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(recordings);
      await prefs.setString(_localRecordingsKey, jsonString);
      print('📁 로컬 녹음 파일 ${recordings.length}개 저장됨');
    } catch (e) {
      print('❌ 로컬 녹음 파일 저장 실패: $e');
      rethrow;
    }
  }

  Future<void> saveRecordingInfo(Map<String, dynamic> recordingInfo) async {
    try {
      final recordings = await loadLocalRecordings();
      recordings.add(recordingInfo);
      await saveLocalRecordings(recordings);
      print('📁 녹음 정보 저장됨: ${recordingInfo['fileName']}');
    } catch (e) {
      print('❌ 녹음 정보 저장 실패: $e');
      rethrow;
    }
  }

  Future<void> updateRecordingInfo(Map<String, dynamic> updates) async {
    try {
      final recordings = await loadLocalRecordings();
      final index = recordings.indexWhere((recording) => recording['filePath'] == updates['filePath']);
      
      if (index != -1) {
        recordings[index] = {...recordings[index], ...updates};
        await saveLocalRecordings(recordings);
        print('📁 녹음 정보 업데이트됨: ${recordings[index]['fileName']}');
      } else {
        throw Exception('Recording not found: ${updates['filePath']}');
      }
    } catch (e) {
      print('❌ 녹음 정보 업데이트 실패: $e');
      rethrow;
    }
  }
  Future<List<Map<String, dynamic>>> loadLocalRecordings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_localRecordingsKey) ?? '[]';
      final List<dynamic> decoded = json.decode(jsonString);
      
      // 실제 파일 존재 여부 확인
      List<Map<String, dynamic>> validRecordings = [];
      for (var item in decoded) {
        final file = File(item['filePath']);
        if (await file.exists()) {
          validRecordings.add(Map<String, dynamic>.from(item));
        }
      }
      
      print('📁 로컬 녹음 파일 ${validRecordings.length}개 로드됨');
      return validRecordings;
    } catch (e) {
      print('❌ 로컬 녹음 파일 로드 실패: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createRecordingInfo(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      final fileName = filePath.split('/').last;
      final timestamp = DateTime.now().toIso8601String();
      
      return {
        'fileName': fileName,
        'filePath': filePath,
        'fileSize': fileSize,
        'timestamp': timestamp,
        'uploaded': false,
        'uploadAttempts': 0,
      };
    } catch (e) {
      print('❌ 녹음 정보 생성 실패: $e');
      rethrow;
    }
  }

  Future<void> deleteLocalFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      print('🗑️ 로컬 파일 삭제됨: ${filePath.split('/').last}');
    } catch (e) {
      print('❌ 로컬 파일 삭제 실패: $e');
      rethrow;
    }
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}