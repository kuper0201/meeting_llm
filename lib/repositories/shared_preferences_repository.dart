import '../interfaces/storage_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SharedPreferencesRepository implements IStorageRepository<Map<String, dynamic>> {
  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(data));
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    if (jsonString != null) {
      return Map<String, dynamic>.from(json.decode(jsonString));
    }
    return null;
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  @override
  Future<List<Map<String, dynamic>>> loadAll() async {
    // SharedPreferences는 모든 키를 반환하는 기능이 제한적이므로
    // 특정 패턴의 키들만 반환
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('recording_'));
    
    List<Map<String, dynamic>> results = [];
    for (String key in keys) {
      final data = await load(key);
      if (data != null) results.add(data);
    }
    return results;
  }
}