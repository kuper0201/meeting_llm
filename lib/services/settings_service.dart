import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _serverUrlKey = 'server_url';

  Future<void> saveServerUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_serverUrlKey, url);
    } catch (e) {
      print('❌ 서버 URL 저장 실패: $e');
      rethrow;
    }
  }

  Future<String> loadServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_serverUrlKey) ?? '';
    } catch (e) {
      print('❌ 서버 URL 로드 실패: $e');
      return '';
    }
  }
}