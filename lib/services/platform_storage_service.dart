import 'package:path_provider/path_provider.dart';
import 'dart:io';

class PlatformStorageService {
  /// 플랫폼별 최적 저장 경로 반환
  static Future<String> getOptimalStoragePath() async {
    if (Platform.isAndroid) {
      return await _getAndroidAudioPath();
    } else if (Platform.isMacOS) {
      return await _getMacOSDocumentsPath();
    } else if (Platform.isIOS) {
      return await _getIOSDocumentsPath();
    } else if (Platform.isWindows) {
      return await _getWindowsDocumentsPath();
    } else if (Platform.isLinux) {
      return await _getLinuxDocumentsPath();
    } else {
      // 기본값: Documents 디렉토리
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }
  }

  /// Android: 오디오 디렉토리 (Music/Audio 폴더)
  static Future<String> _getAndroidAudioPath() async {
    try {
      // 1순위: 외부 저장소의 Music 디렉토리
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // /storage/emulated/0/Android/data/com.example.record_meet/files/Music
        final musicDir = Directory('${externalDir.path}/Music');
        if (!await musicDir.exists()) {
          await musicDir.create(recursive: true);
        }
        return musicDir.path;
      }
    } catch (e) {
      print('⚠️ Android 외부 저장소 접근 실패: $e');
    }

    try {
      // 2순위: 다운로드 디렉토리
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final audioDir = Directory('${downloadsDir.path}/RecordMeet');
        if (!await audioDir.exists()) {
          await audioDir.create(recursive: true);
        }
        return audioDir.path;
      }
    } catch (e) {
      print('⚠️ Android 다운로드 디렉토리 접근 실패: $e');
    }

    // 3순위: 앱 내부 Documents (fallback)
    final documentsDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${documentsDir.path}/Audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir.path;
  }

  /// macOS: 사용자 Documents 디렉토리
  static Future<String> _getMacOSDocumentsPath() async {
    try {
      // 사용자의 실제 Documents 폴더
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        final userDocuments = Directory('$homeDir/Documents/RecordMeet');
        if (!await userDocuments.exists()) {
          await userDocuments.create(recursive: true);
        }
        return userDocuments.path;
      }
    } catch (e) {
      print('⚠️ macOS 사용자 Documents 접근 실패: $e');
    }

    // Fallback: 앱 Documents 디렉토리
    final documentsDir = await getApplicationDocumentsDirectory();
    return documentsDir.path;
  }

  /// iOS: 앱 Documents 디렉토리
  static Future<String> _getIOSDocumentsPath() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${documentsDir.path}/Recordings');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir.path;
  }

  /// Windows: 사용자 Documents 디렉토리
  static Future<String> _getWindowsDocumentsPath() async {
    try {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final userDocuments = Directory('$userProfile\\Documents\\RecordMeet');
        if (!await userDocuments.exists()) {
          await userDocuments.create(recursive: true);
        }
        return userDocuments.path;
      }
    } catch (e) {
      print('⚠️ Windows 사용자 Documents 접근 실패: $e');
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    return documentsDir.path;
  }

  /// Linux: 사용자 Documents 디렉토리
  static Future<String> _getLinuxDocumentsPath() async {
    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        final userDocuments = Directory('$homeDir/Documents/RecordMeet');
        if (!await userDocuments.exists()) {
          await userDocuments.create(recursive: true);
        }
        return userDocuments.path;
      }
    } catch (e) {
      print('⚠️ Linux 사용자 Documents 접근 실패: $e');
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    return documentsDir.path;
  }

  /// 날짜별 하위 폴더 생성
  static Future<String> createDateBasedDirectory(String basePath) async {
    final now = DateTime.now();
    final dateFolder = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final dateDir = Directory('$basePath/$dateFolder');
    
    if (!await dateDir.exists()) {
      await dateDir.create(recursive: true);
    }
    
    return dateDir.path;
  }

  /// 저장 경로 정보 반환
  static Future<Map<String, String>> getStorageInfo() async {
    final info = <String, String>{};
    
    info['platform'] = Platform.operatingSystem;
    info['optimalPath'] = await getOptimalStoragePath();
    
    if (Platform.isAndroid) {
      info['description'] = 'Android 오디오 디렉토리 (Music 폴더)';
      info['userVisible'] = 'true';
    } else if (Platform.isMacOS) {
      info['description'] = 'macOS 사용자 Documents 폴더';
      info['userVisible'] = 'true';
    } else if (Platform.isIOS) {
      info['description'] = 'iOS 앱 Documents 폴더';
      info['userVisible'] = 'false';
    } else {
      info['description'] = '기본 Documents 폴더';
      info['userVisible'] = 'false';
    }
    
    return info;
  }

  /// 저장 경로를 시스템 파일 탐색기에서 열기
  static Future<void> openInSystemExplorer() async {
    try {
      final path = await getOptimalStoragePath();
      
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      } else {
        print('⚠️ 현재 플랫폼에서는 파일 탐색기 열기를 지원하지 않습니다.');
      }
    } catch (e) {
      print('❌ 파일 탐색기 열기 실패: $e');
    }
  }
}