import '../interfaces/storage_repository.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class FileStorageRepository implements IStorageRepository<Map<String, dynamic>> {
  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$key.json');
    await file.writeAsString(json.encode(data));
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$key.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return Map<String, dynamic>.from(json.decode(content));
      }
    } catch (e) {
      print('❌ 파일 로드 실패: $e');
    }
    return null;
  }

  @override
  Future<void> delete(String key) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$key.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadAll() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync()
        .where((entity) => entity.path.endsWith('.json'))
        .cast<File>();
    
    List<Map<String, dynamic>> results = [];
    for (File file in files) {
      try {
        final content = await file.readAsString();
        results.add(Map<String, dynamic>.from(json.decode(content)));
      } catch (e) {
        print('❌ 파일 읽기 실패: ${file.path}');
      }
    }
    return results;
  }
}