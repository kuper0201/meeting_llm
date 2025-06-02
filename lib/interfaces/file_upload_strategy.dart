// 업로드 전략을 추상화
abstract class IFileUploadStrategy {
  Future<bool> upload(String filePath, Map<String, String> metadata);
}