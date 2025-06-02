import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class ServerCommunicationService {
  Future<bool> uploadFile(String serverUrl, String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('파일이 존재하지 않습니다');
      }
      
      final cleanUrl = _cleanServerUrl(serverUrl);
      final uploadUrl = '${cleanUrl}upload-audio/';
      
      print('📤 업로드 시도: ${filePath.split('/').last} -> http://$uploadUrl');
      
      var request = http.MultipartRequest('POST', Uri.parse('http://$uploadUrl'));
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      
      print('📡 업로드 응답: ${response.statusCode}');
      print('📝 응답 내용: $responseBody');
      
      return response.statusCode == 200;
    } catch (e) {
      print('💥 업로드 중 예외: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchTranscriptions(String serverUrl) async {
    try {
      final cleanUrl = _cleanServerUrl(serverUrl);
      final transcriptionUrl = '${cleanUrl}transcriptions/';
      
      final response = await http.get(
        Uri.parse('http://$transcriptionUrl'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['transcriptions']);
      } else {
        throw Exception('데이터를 가져올 수 없습니다 (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Transcription 조회 실패: $e');
      rethrow;
    }
  }

  Future<bool> deleteTranscription(String serverUrl, int transcriptionId) async {
    try {
      final cleanUrl = _cleanServerUrl(serverUrl);
      final deleteUrl = '${cleanUrl}delete/$transcriptionId';
      
      print('🗑️ 삭제 요청 URL: http://$deleteUrl');
      
      final response = await http.delete(
        Uri.parse('http://$deleteUrl'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
      );
      
      print('📡 삭제 응답 상태 코드: ${response.statusCode}');
      print('📝 삭제 응답: ${response.body}');
      
      return response.statusCode == 200;
    } catch (e) {
      print('💥 삭제 중 예외 발생: $e');
      rethrow;
    }
  }

  String _cleanServerUrl(String serverUrl) {
    return serverUrl
        .replaceAll('/upload-audio/', '')
        .replaceAll('upload-audio', '')
        .replaceAll(RegExp(r'/$'), '') + '/';
  }
}