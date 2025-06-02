import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'bindings/app_bindings.dart';
import 'pages/recorder_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Meeting LLM',
      debugShowCheckedModeBanner: false,
      initialBinding: AppBindings(), // AppBindings에 RecorderController 등록
      initialRoute: '/',
      getPages: [
        GetPage(
          name: '/',
          page: () => RecorderPage(),
        ),
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}