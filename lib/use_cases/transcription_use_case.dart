import '../services/server_communication_service.dart';

class TranscriptionUseCase {
  final ServerCommunicationService _serverService;

  TranscriptionUseCase(this._serverService);

  Future<List<Map<String, dynamic>>> fetchTranscriptions(String serverUrl) async {
    if (serverUrl.isEmpty) {
      throw Exception('서버 주소를 입력해주세요');
    }
    
    return await _serverService.fetchTranscriptions(serverUrl);
  }

  Future<bool> deleteTranscription(String serverUrl, int transcriptionId) async {
    if (serverUrl.isEmpty) {
      throw Exception('서버 주소를 입력해주세요');
    }
    
    return await _serverService.deleteTranscription(serverUrl, transcriptionId);
  }
}