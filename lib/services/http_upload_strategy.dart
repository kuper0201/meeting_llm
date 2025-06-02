import '../interfaces/file_upload_strategy.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class HttpUploadStrategy implements IFileUploadStrategy {
  final String serverUrl;
  
  HttpUploadStrategy(this.serverUrl);

  @override
  Future<bool> upload(String filePath, Map<String, String> metadata) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      
      final uploadUrl = _buildUploadUrl();
      
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      
      // 메타데이터 추가
      request.fields.addAll(metadata);
      
      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print('❌ HTTP 업로드 실패: $e');
      return false;
    }
  }

  String _buildUploadUrl() {
    final cleanUrl = serverUrl
        .replaceAll('/upload-audio/', '')
        .replaceAll('upload-audio', '')
        .replaceAll(RegExp(r'/$'), '');
    return 'http://$cleanUrl/upload-audio/';
  }
}