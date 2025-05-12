import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'dart:typed_data';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'dart:io';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isCameraReady = false;
  CameraController? cameraController;
  String? result;
  late ObjectDetector objectDetector;
  List<CameraDescription> cameras = [];
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    cameras = await availableCameras();
    _initializeDetector();
    initCamera();
  }

  void _initializeDetector() {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );
    objectDetector = ObjectDetector(options: options);
    print('Detector inicializado con opciones: ${options.mode}');
  }

  Future<void> initCamera() async {
    try {
      cameraController = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid
                ? ImageFormatGroup.yuv420
                : ImageFormatGroup.bgra8888,
      );

      await cameraController!.initialize();

      // Agregar un pequeño retraso antes Ede iniciar el stream
      await Future.delayed(const Duration(milliseconds: 500));

      await cameraController?.startImageStream(_processCameraImage);

      if (mounted) {
        setState(() {
          isCameraReady = true;
        });
      }
    } catch (e) {
      print('Error de inicialización de cámara: $e');
    }
  }

  static InputImageFormat _detectImageFormat(CameraImage image) {
    if (Platform.isAndroid) {
      return InputImageFormat.yuv420; // Formato para Android
    } else {
      return InputImageFormat.bgra8888; // Formato para iOS
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      // Detectar formato automáticamente
      final inputFormat = _detectImageFormat(image);

      print('Formato detectado: ${inputFormat.name}');
      print('Tamaño de imagen: ${image.width}x${image.height}');
      print('Bytes por fila: ${image.planes[0].bytesPerRow}');

      // Convertir la imagen
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }

      final inputImage = InputImage.fromBytes(
        bytes: allBytes.done().buffer.asUint8List(),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: inputFormat, // Usar el formato detectado
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      // Procesar la imagen
      final objects = await objectDetector.processImage(inputImage);
      print('Objetos detectados: ${objects.length}');

      if (mounted) {
        setState(() {
          if (objects.isNotEmpty) {
            result = objects
                .map(
                  (obj) => obj.labels
                      .map(
                        (label) =>
                            '${label.text} (${(label.confidence * 100).toStringAsFixed(1)}%)',
                      )
                      .join(', '),
                )
                .join('\n');
          } else {
            result = 'No se detectaron objetos';
          }
        });
      }
    } catch (e) {
      print('Error detallado: $e');
    } finally {
      _isBusy = false;
    }
  }

  @override
  void dispose() {
    cameraController?.dispose();
    objectDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const SizedBox(height: 40),
          if (isCameraReady)
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CameraPreview(cameraController!),
                    ),
                  ),
                ),
                // Indicador de detección activa
                Positioned(
                  top: 10,
                  right: 30,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isBusy ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          // Mostrar resultados con estilo
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result ?? "Esperando detecciones...",
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
