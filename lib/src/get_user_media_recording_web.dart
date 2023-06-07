// ignore: uri_does_not_exist
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:html' as webFile;
import 'dart:html';
import 'dart:math';
import 'dart:io' as io;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../constants/video_size.dart';

/*
 * getUserMedia sample
 */
class GetUserMediaSample extends StatefulWidget {
  static String tag = 'get_usermedia_sample';

  @override
  _GetUserMediaSampleState createState() => _GetUserMediaSampleState();
}

class _GetUserMediaSampleState extends State<GetUserMediaSample> {
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  MediaRecorder? _mediaRecorder;
  List<MediaDeviceInfo> _devices = [];
  bool get _isRec => _mediaRecorder != null;
  List<dynamic>? cameras;

  bool _logEvents = false;
  bool _onDevice = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = '';
  String lastError = '';
  String lastStatus = '';
  String _currentLocaleId = '';
  final SpeechToText speech = SpeechToText();
  String? _selectedVideoFPS = '30';
  VideoSize _selectedVideoSize = VideoSize(1280, 720);
  String? _selectedVideoInputId;
  List<MediaDeviceInfo>? _cameras;
  var senders = <RTCRtpSender>[];
  List<LocaleName> _localeNames = [];

  @override
  void initState() {
    super.initState();
    initRenderers();
    initSpeechState();
    loadDevices();
    changeMicrofone();
    navigator.mediaDevices.ondevicechange = (event) {
      loadDevices();
    };
    _makeCall();
    Timer(const Duration(seconds: 10), () {
      verifySpeech();
    });
    navigator.mediaDevices.enumerateDevices().then((md) {
      setState(() {
        cameras = md.where((d) => d.kind == 'videoinput').toList();
      });
    });
  }

  Future<void> changeMicrofone() async {
    navigator.mediaDevices.enumerateDevices().then((devices) {
      // Filtrar apenas os dispositivos de áudio
      List<MediaDeviceInfo> audioDevices =
          devices.where((device) => device.kind == 'audioinput').toList();

      // Exiba a lista de dispositivos de áudio
      for (var device in audioDevices) {
        print('Dispositivo de áudio: ${device.label}');
      }
    });
  }

  Future<void> verifySpeech() async {
    Timer.periodic(const Duration(seconds: 2), (timer) {
      lastWords.contains("pause") == true ? _hangUp : null;
      lastWords.contains("foto") == true ? _captureFrame() : null;
      lastWords.contains("gravar") == true ? _startRecording() : null;
      lastWords.contains("parar") == true ? _stopRecording() : null;
    });
  }

  Future<void> loadDevices() async {
    if (WebRTC.platformIsAndroid || WebRTC.platformIsIOS) {
      //Ask for runtime permissions if necessary.
      var status = await Permission.bluetooth.request();
      if (status.isPermanentlyDenied) {
        print('BLEpermdisabled');
      }

      status = await Permission.bluetoothConnect.request();
      if (status.isPermanentlyDenied) {
        print('ConnectPermdisabled');
      }
    }
    final devices = await navigator.mediaDevices.enumerateDevices();
    setState(() {
      _devices = devices;
    });
  }

  Future<void> _selectVideoFps(String fps) async {
    _selectedVideoFPS = fps;
    if (!_inCalling) {
      return;
    }
    await _selectVideoInput(_selectedVideoInputId);
    setState(() {});
  }

  Future<void> _selectVideoSize(String size) async {
    _selectedVideoSize = VideoSize.fromString(size);
    if (!_inCalling) {
      return;
    }
    await _selectVideoInput(_selectedVideoInputId);
    setState(() {});
  }

  Future<void> _selectVideoInput(String? deviceId) async {
    _selectedVideoInputId = deviceId;
    if (!_inCalling) {
      return;
    }
    // 2) replace track.
    // stop old track.
    _localRenderer.srcObject = null;

    _localStream?.getTracks().forEach((track) async {
      await track.stop();
    });
    await _localStream?.dispose();

    var newLocalStream = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {
        if (_selectedVideoInputId != null && kIsWeb)
          'deviceId': _selectedVideoInputId,
        if (_selectedVideoInputId != null && !kIsWeb)
          'optional': [
            {'sourceId': _selectedVideoInputId}
          ],
        'width': _selectedVideoSize.width,
        'height': _selectedVideoSize.height,
        'frameRate': _selectedVideoFPS,
      },
    });
    _localStream = newLocalStream;
    _localRenderer.srcObject = _localStream;
    // replace track.
    var newTrack = _localStream?.getVideoTracks().first;
    setState(() {});
    print('track.settings ' + newTrack!.getSettings().toString());
  }

  @override
  void deactivate() {
    super.deactivate();
    if (_inCalling) {
      _stop();
    }
    _localRenderer.dispose();
    navigator.mediaDevices.ondevicechange = null;
  }

  void initRenderers() async {
    await _localRenderer.initialize();
  }

  void startListening() {
    _logEvent('start listening');
    lastWords = '';
    lastError = '';

    speech.listen(
      onResult: resultListener,
      partialResults: true,
      localeId: _currentLocaleId,
      onSoundLevelChange: soundLevelListener,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
      onDevice: _onDevice,
    );
    setState(() {});
  }

  void stopListening() async {
    _logEvent('stop');
    await speech.stop();
    if (!mounted) return;
    setState(() {
      level = 0.0;
      lastWords = "";
    });
  }

  void cancelListening() {
    _logEvent('cancel');
    speech.cancel();
    setState(() {
      level = 0.0;
    });
  }

  void _logEvent(String eventDescription) {
    if (_logEvents) {
      var eventTime = DateTime.now().toIso8601String();
      print('$eventTime $eventDescription');
    }
  }

  void resultListener(SpeechRecognitionResult result) {
    for (var res in result.alternates) {
      print("Falando --> ${res.recognizedWords}");
      setState(() {
        lastWords = '${res.recognizedWords}';
      });
    }
    _logEvent(
        'Result listener final: ${result.finalResult}, words: ${result.recognizedWords}');
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    setState(() {
      this.level = level;
    });
  }

  void errorListener(SpeechRecognitionError error) {
    _logEvent(
        'Received error status: $error, listening: ${speech.isListening}');
    setState(() {
      lastError = '${error.errorMsg} - ${error.permanent}';
    });
  }

  void statusListener(String status) {
    _logEvent(
        'Received listener status: $status, listening: ${speech.isListening}');
    setState(() {
      lastStatus = '$status';
    });
  }

  Future<void> initSpeechState() async {
    _logEvent('Initialize');
    try {
      var hasSpeech = await speech.initialize(
        onError: errorListener,
        onStatus: statusListener,
        debugLogging: _logEvents,
      );
      if (hasSpeech) {
        _localeNames = await speech.locales();
        var systemLocale = await speech.systemLocale();
        _currentLocaleId = systemLocale?.localeId ?? '';
      }
      if (!mounted) return;
    } catch (e) {
      setState(() {
        lastError = 'Speech recognition failed: ${e.toString()}';
      });
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  void _makeCall() async {
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth':
              '1280', // Provide your own width, height and frame rate here
          'minHeight': '720',
          'minFrameRate': '30',
        },
      }
    };

    try {
      var stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _cameras = await Helper.cameras;
      _localStream = stream;
      _localRenderer.srcObject = _localStream;
      startListening();
    } catch (e) {
      print(e.toString());
    }
    if (!mounted) return;

    setState(() {
      _inCalling = true;
    });
  }

  Future<void> _stop() async {
    try {
      stopListening();
      if (kIsWeb) {
        _localStream?.getTracks().forEach((track) => track.stop());
      }
      await _localStream?.dispose();
      _localStream = null;
      _localRenderer.srcObject = null;
    } catch (e) {
      print(e.toString());
    }
  }

  void _hangUp() async {
    await _stop();
    setState(() {
      lastWords = "";
      _inCalling = false;
    });
  }

  void _startRecording() async {
    setState(() {
      lastWords = "";
    });
    if (_localStream == null) throw Exception('Can\'t record without a stream');
    _mediaRecorder = MediaRecorder();
    setState(() {});
    _mediaRecorder?.startWeb(_localStream!);
  }

  void _stopRecording() async {
    setState(() {
      lastWords = "";
    });
    final objectUrl = await _mediaRecorder?.stop();

    webFile.AnchorElement(
      href: objectUrl,
    )
      ..setAttribute("download", "${objectUrl.split('/')[3]}.mp4")
      ..click();

    setState(() {
      _mediaRecorder = null;
    });
  }

  void _captureFrame() async {
    final player = AudioPlayer();
    await player.play(DeviceFileSource("assets/player/foto-player.mp3"));
    setState(() {
      lastWords = "";
    });
    if (_localStream == null) throw Exception('Can\'t record without a stream');
    final videoTrack = _localStream!
        .getVideoTracks()
        .firstWhere((track) => track.kind == 'video');

    final frame = await videoTrack.captureFrame();

    if (kIsWeb) {
      var blob = webFile.Blob([frame.asUint8List()], "image/jpeg", "native");

      webFile.AnchorElement(
        href: webFile.Url.createObjectUrlFromBlob(blob).toString(),
      )
        ..setAttribute("download", "image.jpeg")
        ..click();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width / 0.8,
                height: MediaQuery.of(context).size.height / 1.1,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: RTCVideoView(_localRenderer, mirror: true),
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  /*SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            textStyle: const TextStyle(color: Colors.white),
                            backgroundColor:
                                _inCalling ? Colors.red : Colors.cyan,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5))),
                        onPressed: _inCalling ? _hangUp : _makeCall,
                        child: _inCalling
                            ? const Text("Encerrar video",
                                style: TextStyle(color: Colors.white))
                            : const Text("Iniciar video",
                                style: TextStyle(color: Colors.white))),
                  ),*/
                  const SizedBox(
                    width: 20,
                  ),
                  _inCalling
                      ? SizedBox(
                          width: 200,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyan,
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                ),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5))),
                            onPressed: _captureFrame,
                            child: const Text("Capturar foto",
                                style: TextStyle(color: Colors.white)),
                          ),
                        )
                      : const Text(""),
                  const SizedBox(
                    width: 20,
                  ),
                  _inCalling
                      ? SizedBox(
                          width: 200,
                          height: 50,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _isRec ? Colors.red : Colors.cyan,
                                  textStyle:
                                      const TextStyle(color: Colors.white),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5))),
                              onPressed: () {
                                _isRec ? _stopRecording : _startRecording;
                              },
                              child: _isRec
                                  ? const Row(
                                      children: [
                                        Text("Encerrar gravação",
                                            style:
                                                TextStyle(color: Colors.white)),
                                        Icon(Icons.stop, color: Colors.red),
                                      ],
                                    )
                                  : const Row(
                                      children: [
                                        Text("Iniciar gravação",
                                            style:
                                                TextStyle(color: Colors.white)),
                                        Icon(Icons.fiber_manual_record,
                                            color: Colors.red),
                                      ],
                                    )),
                        )
                      : const Text(""),
                  PopupMenuButton<String>(
                    onSelected: _switchCamera,
                    itemBuilder: (BuildContext context) {
                      if (_cameras != null) {
                        return _cameras!.map((device) {
                          return PopupMenuItem<String>(
                            value: device.deviceId,
                            child: Text(device.label),
                          );
                        }).toList();
                      } else {
                        return [];
                      }
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: _selectVideoFps,
                    icon: Icon(Icons.menu),
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem<String>(
                          value: _selectedVideoFPS,
                          child: Text('Select FPS ($_selectedVideoFPS)'),
                        ),
                        PopupMenuDivider(),
                        ...['8', '15', '30', '60']
                            .map((fps) => PopupMenuItem<String>(
                                  value: fps,
                                  child: Text(fps),
                                ))
                            .toList()
                      ];
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: _selectVideoSize,
                    icon: Icon(Icons.screenshot_monitor),
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem<String>(
                          value: _selectedVideoSize.toString(),
                          child:
                              Text('Select Video Size ($_selectedVideoSize)'),
                        ),
                        PopupMenuDivider(),
                        ...['320x240', '640x480', '1280x720', '1920x1080']
                            .map((fps) => PopupMenuItem<String>(
                                  value: fps,
                                  child: Text(fps),
                                ))
                            .toList()
                      ];
                    },
                  ),
                ],
              )
            ],
          );
        },
      ),
    );
  }

  void _switchCamera(String deviceId) async {
    if (_localStream == null) return;

    await Helper.switchCamera(
        _localStream!.getVideoTracks()[0], deviceId, _localStream);
    _localRenderer.srcObject = _localStream;
    setState(() {});
  }
}
