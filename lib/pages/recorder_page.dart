import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../states/recorder_controller.dart';
import 'dart:io';

class RecorderPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<RecorderController>();
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meeting LLM'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.folder), text: '로컬 파일'),
              Tab(icon: Icon(Icons.transcribe), text: '전사 목록'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '전사 목록 새로고침',
              onPressed: () => controller.fetchTranscriptions(),
            ),
            IconButton(
              icon: const Icon(Icons.wifi),
              tooltip: '서버 연결 테스트',
              onPressed: () => controller.testServerConnection(),
            ),
            if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
              IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: '저장 폴더 열기',
                onPressed: () => controller.openStorageFolder(),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'upload_all':
                    controller.uploadAllPendingFiles();
                    break;
                  case 'refresh_local':
                    controller.loadLocalRecordings();
                    break;
                  case 'open_storage':
                    controller.openStorageFolder();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'upload_all',
                  child: Row(
                    children: [
                      Icon(Icons.cloud_upload),
                      SizedBox(width: 8),
                      Text('모든 파일 업로드'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh_local',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('로컬 파일 새로고침'),
                    ],
                  ),
                ),
                if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
                  const PopupMenuItem(
                    value: 'open_storage',
                    child: Row(
                      children: [
                        Icon(Icons.folder_open),
                        SizedBox(width: 8),
                        Text('저장 폴더 열기'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // 서버 URL 입력
            _buildServerUrlSection(controller),
            
            // 저장 경로 정보
            _buildStorageInfoSection(controller),
            
            // 녹음 컨트롤
            _buildRecordingControls(context, controller),
            
            // 상태 표시
            _buildStatusSection(controller),
            
            // 탭 뷰
            Expanded(
              child: TabBarView(
                children: [
                  _buildLocalFilesTab(controller),
                  _buildTranscriptionsTab(controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildServerUrlSection(RecorderController controller) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: controller.urlTextController,
        decoration: InputDecoration(
          labelText: '서버 주소',
          hintText: 'http://192.168.1.100:8000',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.computer),
        ),
        onChanged: (value) => controller.saveServerUrl(),
      ),
    );
  }

  Widget _buildStorageInfoSection(RecorderController controller) {
    return Obx(() {
      if (controller.storageInfo.isEmpty) {
        return const SizedBox.shrink();
      }
      
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(
              _getStorageIcon(),
              color: Colors.blue[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                controller.getStorageInfoText(),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
            if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 16),
                onPressed: () => controller.openStorageFolder(),
                tooltip: '폴더 열기',
              ),
          ],
        ),
      );
    });
  }

  IconData _getStorageIcon() {
    if (Platform.isAndroid) return Icons.music_note;
    if (Platform.isMacOS) return Icons.folder;
    if (Platform.isWindows) return Icons.folder;
    if (Platform.isLinux) return Icons.folder;
    return Icons.storage;
  }

  Widget _buildRecordingControls(BuildContext context, RecorderController controller) {
    return Obx(() {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 녹음 버튼
            ElevatedButton.icon(
              onPressed: controller.isRecording.value 
                  ? controller.stopRecording 
                  : controller.startRecording,
              icon: Icon(controller.isRecording.value ? Icons.stop : Icons.mic),
              label: Text(controller.isRecording.value ? '녹음 중지' : '녹음 시작'),
              style: ElevatedButton.styleFrom(
                backgroundColor: controller.isRecording.value ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            
            // 진폭 표시
            if (controller.isRecording.value) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.graphic_eq, color: Colors.red),
                  const SizedBox(height: 10),
                  Container(
                    width: 100,
                    height: 20,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Obx(() {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: (controller.amplitude.value + 160) / 160 * MediaQuery.of(context).size.width * 0.9,
                          height: 20,
                          color: Colors.blueAccent,
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
  Widget _buildStatusSection(RecorderController controller) {
    return Obx(() {
      if (controller.uploadStatus.value.isEmpty) {
        return const SizedBox.shrink();
      }
      
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          children: [
            if (controller.isUploadingFile.value)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.info, color: Colors.blue[600], size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                controller.uploadStatus.value,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[800],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // 서버 목록 탭
  Widget _buildServerTab(RecorderController controller) {
    return Column(
      children: [
        // Transcription 목록 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Transcription 목록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              onPressed: controller.fetchTranscriptions,
              child: const Text('목록 불러오기'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        // Transcription 목록
        Expanded(
          child: Obx(() {
            if (controller.isLoadingTranscriptions.value) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (controller.transcriptionError.value.isNotEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      controller.transcriptionError.value,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: controller.fetchTranscriptions,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              );
            }
            
            if (controller.transcriptions.isEmpty) {
              return const Center(
                child: Text('Transcription 데이터가 없습니다.'),
              );
            }
            
            return ListView.builder(
              itemCount: controller.transcriptions.length,
              itemBuilder: (context, index) {
                final transcription = controller.transcriptions[index];
                final transcriptionId = transcription['id'] as int;
                final filename = transcription['filename'] ?? 'Unknown';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            filename,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        // 삭제 버튼
                        Obx(() => IconButton(
                          icon: controller.isDeletingTranscription.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.delete, color: Colors.red),
                          onPressed: controller.isDeletingTranscription.value
                              ? null
                              : () async {
                                  final confirmed = await controller.showDeleteConfirmDialog(filename);
                                  if (confirmed) {
                                    await controller.deleteTranscription(transcriptionId);
                                  }
                                },
                          tooltip: '삭제',
                        )),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Duration: ${transcription['duration']}초'),
                        Text('Created: ${transcription['created_at']}'),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (transcription['text'] != null && transcription['text'].toString().isNotEmpty) ...[
                              const Text(
                                'Transcription:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Text(transcription['text']),
                              const SizedBox(height: 10),
                            ],
                            if (transcription['summary'] != null && transcription['summary'].toString().isNotEmpty) ...[
                              const Text(
                                'Summary:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Text(transcription['summary']),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
  // 로컬 파일 탭
  Widget _buildLocalFilesTab(RecorderController controller) {
    return Obx(() {
      if (controller.isLoadingLocalFiles.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.localRecordings.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '저장된 녹음 파일이 없습니다',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                '녹음을 시작해보세요',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: controller.localRecordings.length,
        itemBuilder: (context, index) {
          final recording = controller.localRecordings[index];
          return _buildLocalFileCard(controller, recording, index);
        },
      );
    });
  }

  Widget _buildLocalFileCard(RecorderController controller, Map<String, dynamic> recording, int index) {
    final fileName = recording['fileName'] ?? 'Unknown';
    final isCurrentlyUploading = controller.currentUploadingFile.value == fileName;
    final isCurrentlyPlaying = controller.currentPlayingFile == fileName;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 파일명과 상태 아이콘
            Row(
              children: [
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  controller.getUploadStatusIcon(recording),
                  color: controller.getUploadStatusColor(recording),
                  size: 20,
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // 파일 정보
            Text(
              controller.getRecordingInfoText(recording),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 재생 컨트롤 (재생 중인 파일만)
            if (isCurrentlyPlaying) ...[
              _buildPlaybackControls(controller),
              const SizedBox(height: 12),
            ],
            
            // 액션 버튼들
            Row(
              children: [
                // 재생/일시정지 버튼
                IconButton(
                  onPressed: () => controller.playAudio(
                    recording['filePath'],
                    fileName,
                  ),
                  icon: Icon(
                    isCurrentlyPlaying && controller.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  tooltip: isCurrentlyPlaying && controller.isPlaying ? '일시정지' : '재생',
                ),
                
                // 업로드 버튼
                if (recording['uploaded'] != true)
                  IconButton(
                    onPressed: isCurrentlyUploading
                        ? null
                        : () => controller.uploadLocalFile(recording),
                    icon: isCurrentlyUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    tooltip: '업로드',
                  ),
                
                const Spacer(),
                
                // 삭제 버튼
                IconButton(
                  onPressed: () async {
                    final confirmed = await controller.showDeleteConfirmDialog(fileName);
                    if (confirmed) {
                      await controller.deleteLocalFile(recording);
                    }
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: '삭제',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackControls(RecorderController controller) {
    return Obx(() {
      return Column(
        children: [
          // 진행률 슬라이더
          SliderTheme(
            data: SliderTheme.of(Get.context!).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 2,
            ),
            child: Slider(
              value: controller.playbackProgress.clamp(0.0, 1.0),
              onChanged: (value) => controller.seekAudio(value),
              activeColor: Colors.blue,
              inactiveColor: Colors.grey[300],
            ),
          ),
          
          // 시간 표시
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(controller.formatDuration(controller.playbackPosition)),
                Text(controller.formatDuration(controller.playbackDuration)),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildTranscriptionsTab(RecorderController controller) {
    return Obx(() {
      if (controller.isLoadingTranscriptions.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.transcriptionError.value.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                '오류 발생',
                style: TextStyle(fontSize: 18, color: Colors.red[700]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  controller.transcriptionError.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => controller.fetchTranscriptions(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        );
      }

      if (controller.transcriptions.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.transcribe, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '전사된 내용이 없습니다',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                '파일을 업로드하고 잠시 기다려주세요',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: controller.transcriptions.length,
        itemBuilder: (context, index) {
          final transcription = controller.transcriptions[index];
          return _buildTranscriptionCard(controller, transcription);
        },
      );
    });
  }

  Widget _buildTranscriptionCard(RecorderController controller, Map<String, dynamic> transcription) {
    print(transcription);
    final id = transcription['id'];
    final filename = transcription['filename'] ?? 'Unknown';
    final content = transcription['summary'] ?? '';
    final timestamp = transcription['timestamp'] ?? '';
    final duration = transcription['duration'] ?? '';

    String timeText = '';
    if (timestamp.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(timestamp);
        timeText = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        timeText = timestamp;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              filename,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (timeText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirmed = await controller.showDeleteConfirmDialog(filename);
                  if (confirmed && id != null) {
                    await controller.deleteTranscription(id);
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('삭제'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: content.isNotEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      content,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: const Text(
                      '전사 처리 중...',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}