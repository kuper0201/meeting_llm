import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../states/recorder_controller.dart';

class RecorderPage extends StatelessWidget {
  RecorderPage({Key? key}) : super(key: key);

  final RecorderController controller = Get.put(RecorderController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("macOS Audio Recorder")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: controller.urlTextController,
                decoration: const InputDecoration(
                  labelText: "FastAPI 서버 주소 (예: 192.168.0.100:8000/upload-audio/)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              // 🆕 녹음 중에만 시각화 바 표시
              Obx(() {
                if (controller.isRecording.value) {
                  return Column(
                    children: [
                      const Text("실시간 음성 입력"),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
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
                              width: (controller.amplitude.value + 160) / 160 * MediaQuery.of(context).size.width,
                              height: 20,
                              color: Colors.blueAccent,
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                } else {
                  return const SizedBox.shrink();
                }
              }),
              Obx(() => ElevatedButton.icon(
                    onPressed: controller.isRecording.value
                        ? controller.stopRecording
                        : controller.startRecording,
                    icon: Icon(controller.isRecording.value ? Icons.stop : Icons.mic),
                    label: Text(controller.isRecording.value ? "🛑 녹음 중지" : "🎙️ 녹음 시작"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  )),
              const SizedBox(height: 20),
              Obx(() {
                if (controller.uploadStatus.value.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      controller.uploadStatus.value,
                      style: TextStyle(
                        fontSize: 16,
                        color: controller.uploadStatus.value.contains("성공")
                            ? Colors.green
                            : Colors.redAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),
      ),
    );
  }
}