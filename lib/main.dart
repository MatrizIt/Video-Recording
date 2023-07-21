import 'dart:html';

import 'package:dashboard_call_recording/src/get_user_media_recording.dart';
import 'package:dashboard_call_recording/src/get_user_media_recording_web.dart';
//import 'package:dashboard_call_recording/src/get_user_media_recording_web.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'constants/size_constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (WebRTC.platformIsDesktop) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  } else if (WebRTC.platformIsAndroid) {
    //startForegroundService();
  }
  runApp(const MyApp());
}

Future<bool> startForegroundService() async {
  const androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: 'Title of the notification',
    notificationText: 'Text of the notification',
    notificationImportance: AndroidNotificationImportance.Default,
    notificationIcon: AndroidResource(
        name: 'background_icon',
        defType: 'drawable'), // Default is ic_launcher from folder mipmap
  );
  await FlutterBackground.initialize(androidConfig: androidConfig);
  return FlutterBackground.enableBackgroundExecution();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    /*var url = window.location.toString().split("Description=");
    var id = url[0].split("id=")[1];
    var description = url[1];*/

    final isMobile =
        MediaQuery.of(context).size.width < SizeConstants.wideScreenBreakpoint;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Recording',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: GetUserMediaSample("id", "description"),
    );
  }
}
