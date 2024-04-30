import 'dart:io' as io;

import 'package:flutter/material.dart';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_application_1/ultralytics_yolo/ultralytics_yolo.dart';
import 'package:flutter_application_1/ultralytics_yolo/yolo_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final controller = UltralyticsYoloCameraController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: FutureBuilder<bool>(
          future: _checkCameraPermission(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!) {
              return Center(child: CircularProgressIndicator());
            }
            return FutureBuilder<ObjectDetector>(
                future: _initObjectDetectorWithLocalModel(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final predictor = snapshot.data;
                  if (predictor == null) {
                    return Center(child: Text("Failed to load the model"));
                  }

                  return UltralyticsYoloCameraPreview(
                    controller: controller,
                    predictor: predictor,
                    onCameraCreated: () => predictor.loadModel(useGpu: true),
                  );
                });
          },
        ),
      ),
    );
  }

  Future<ObjectDetector> _initObjectDetectorWithLocalModel() async {
    try {
      final modelPath = await _copyModelToLocal('assets/last_int8.tflite');
      final metadataPath = await _copyModelToLocal('assets/metadata.yaml');
      final model = LocalYoloModel(
        id: '',
        task: Task.detect,
        format: Format.tflite,
        modelPath: modelPath,
        metadataPath: metadataPath,
      );
      return ObjectDetector(model: model);
    } catch (e) {
      debugPrint("Failed to initialize object detector: $e");
      rethrow; // rethrow the error to be caught by the FutureBuilder
    }
  }

  Future<String> _copyModelToLocal(String assetPath) async {
    final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
    await io.Directory(dirname(path)).create(recursive: true);
    final file = io.File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }




  Future<bool> _checkCameraPermission() async {
    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
    }
    return cameraStatus.isGranted;
  }
}
