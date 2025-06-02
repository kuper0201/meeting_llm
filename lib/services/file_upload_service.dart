import '../interfaces/file_upload_strategy.dart';

// 업로드 전략을 사용하는 서비스 (Strategy Pattern)
class FileUploadService {
  IFileUploadStrategy _uploadStrategy;
  
  FileUploadService(this._uploadStrategy);
  
  // 런타임에 전략 변경 가능 (OCP 준수)
  void setUploadStrategy(IFileUploadStrategy strategy) {
    _uploadStrategy = strategy;
  }
  
  Future<bool> uploadFile(String filePath, Map<String, String> metadata) async {
    return await _uploadStrategy.upload(filePath, metadata);
  }
}