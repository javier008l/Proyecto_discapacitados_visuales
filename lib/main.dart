import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:reconocer_objetos/MySplashPage.dart';

 
List<CameraDescription> cameras = [];
Future<void> main() async{

  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deteccion de objetos',
     
      home: MySplashPage(),
    );
  }
}
