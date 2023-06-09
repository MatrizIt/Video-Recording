import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'package:dashboard_call_recording/constants/video_size.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:ed_screen_recorder/ed_screen_recorder.dart';

/*
 * getUserMedia sample
 */
class GetUserMediaSampleMobile extends StatefulWidget {
  static String tag = 'get_usermedia_sample';

  @override
  _GetUserMediaSampleMobileState createState() =>
      _GetUserMediaSampleMobileState();
}

class _GetUserMediaSampleMobileState extends State<GetUserMediaSampleMobile> {
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  MediaRecorder? _mediaRecorder;
  bool isSucess = true;
  final player = AudioPlayer();
  bool get _isRec => _mediaRecorder != null;
  List<MediaDeviceInfo>? _mediaDevicesList;
  EdScreenRecorder? screenRecorder;
  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String? _selectedVideoInputId;
  VideoSize _selectedVideoSize = VideoSize(640, 480);
  String? _selectedVideoFPS = '30';
  List<MediaDeviceInfo> _audioDevices = [];
  MediaDeviceInfo? _selectedAudioDevice;
  List<dynamic>? cameras;
  List<MediaDeviceInfo>? _cameras;

  @override
  void initState() {
    super.initState();
    Permission.camera.request();
    Permission.microphone.request();
    Permission.videos.request();
    initRenderers();
    fetchAudioDevices();
    _makeCall();
    screenRecorder = EdScreenRecorder();
    _listen();
    navigator.mediaDevices.ondevicechange = (event) async {
      print('++++++ ondevicechange ++++++');
      _mediaDevicesList = await navigator.mediaDevices.enumerateDevices();
    };
  }

  void initRenderers() async {
    await _localRenderer.initialize();
  }

  void _sendVideoAndFoto(String base64String, String mimeType) async {
    try {
      DateTime data = DateTime.now();

      var token = ((data.day + data.month + data.year) * data.day);
      var tokenToString = token.toString();

      List<int> uint = utf8.encode(tokenToString);

      String token64 = base64.encode(uint);
      int id = 287;

      var header = {
        "Authorization": "$token64",
        "Content-Type": "application/json"
      };
      var body = jsonEncode({
        "id": id,
        "arquivos": [
          {"extensao": "$mimeType", "arquivo": "$base64String"}
        ]
      });

      var res = await http.post(
          Uri.parse(
              "https://saabre-dev.imperiomarinho.com.br/api/SalvarVideoFoto"),
          headers: header,
          body: body);
      if (res.statusCode == 200) {
        setState(() {
          isSucess = true;
        });
      } else {
        setState(() {
          isSucess = false;
        });
      }

      player.stop();
    } catch (e) {
      print("Error -> $e");
    }
  }

  @override
  void deactivate() {
    super.deactivate();
    if (_inCalling) {
      _hangUp();
    }
    _localRenderer.dispose();
    navigator.mediaDevices.ondevicechange = null;
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  void _makeCall() async {
    final mediaConstraints = <String, dynamic>{
      'audio': false,
      'video': {
        'mandatory': {
          'minWidth':
              '640', // Provide your own width, height and frame rate here
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    try {
      var stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _mediaDevicesList = await navigator.mediaDevices.enumerateDevices();
      _cameras = _mediaDevicesList;
      _localStream = stream;
      _localRenderer.srcObject = _localStream;
    } catch (e) {
      print(e.toString());
    }
    if (!mounted) return;

    setState(() {
      _inCalling = true;
    });
  }

  void _hangUp() async {
    try {
      if (kIsWeb) {
        _localStream?.getTracks().forEach((track) => track.stop());
      }
      await _localStream?.dispose();
      _localRenderer.srcObject = null;
      setState(() {
        _inCalling = false;
      });
    } catch (e) {
      print(e.toString());
    }
  }

  void _startRecording() async {
    // if (_localStream == null) throw Exception('Stream is not initialized');
    // if (Platform.isIOS) {
    //   print('Recording is not available on iOS');
    //   return;
    // }
    // // TODO(rostopira): request write storage permission
    // final storagePath = await getExternalStorageDirectory();
    // if (storagePath == null) throw Exception('Can\'t find storagePath');

    // final filePath = storagePath.path + '/webrtc_sample/test.mp4';
    //
    //

    // final videoTrack = _localStream!
    //     .getVideoTracks()
    //     .firstWhere((track) => track.kind == 'video');
    // await _mediaRecorder!.start(
    //   filePath,
    //   videoTrack: videoTrack,
    // );
    try {
      final directory = await getApplicationDocumentsDirectory();
      screenRecorder?.startRecordScreen(
        fileName: 'call',
        audioEnable: true,
        height: 200,
        width: 200,
        dirPathToSave: directory.path,
      );
      _mediaRecorder = MediaRecorder();
      setState(() {});
    } catch (e) {
      print("ERRO AO FAZER ALGO: $e");
    }
  }

  void _stopRecording() async {
    try {
      final response = await screenRecorder?.stopRecord();
      if (response == null) throw Exception("Erro ao gravar reunião");
      final file = (response['file'] as File).readAsBytesSync();
      //downloadFile(file, 'mp4');
      _sendVideoAndFoto(base64Encode(file), 'mp4');
      _mediaRecorder = null;
      setState(() {});
    } catch (e) {
      print("ERRO AO FINALIZAR GRAVAÇÃO: $e");
    }
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

  void _toggleCamera() async {
    if (_localStream == null) throw Exception('Stream is not initialized');

    final videoTrack = _localStream!
        .getVideoTracks()
        .firstWhere((track) => track.kind == 'video');
    await Helper.switchCamera(videoTrack);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('Status: $status');
          if (status == 'done') {
            _speech.stop();
          } else if (status == 'notListening') {
            _speech.listen(
              onResult: onResultSpeech,
              listenMode: stt.ListenMode.dictation,
              partialResults: true,
            );
          }
        },
        onError: (error) {
          print('Erro: $error');
        },
      );
      if (available) {
        _speech.listen(
          onResult: onResultSpeech,
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
        );
      }
    } else {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  void onResultSpeech(result) {
    SpeechRecognitionWords resultados =
        result.alternates[result.alternates.length - 1];
    print(
        "Result --> ${resultados.recognizedWords} + ${resultados.confidence}");
    if (resultados.confidence > 0.1) {
      if (result.alternates[result.alternates.length - 1]
          .toString()
          .contains("pause")) {
        _hangUp();
      } else if (result.alternates[result.alternates.length - 1]
          .toString()
          .contains("foto")) {
        _captureFrame(false);
      } else if (result.alternates[result.alternates.length - 1]
          .toString()
          .contains("gravar")) {
        _startRecording();
      } else if (result.alternates[result.alternates.length - 1]
          .toString()
          .contains("parar")) {
        _stopRecording();
      }
    }
  }

  void _captureFrame(bool isButton) async {
    if (_localStream == null) throw Exception('Stream is not initialized');

    final videoTrack = _localStream!
        .getVideoTracks()
        .firstWhere((track) => track.kind == 'video');
    final frame = await videoTrack.captureFrame();
    // ignore: use_build_context_synchronously
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              content:
                  Image.memory(frame.asUint8List(), height: 720, width: 1280),
              actions: <Widget>[
                TextButton(
                  onPressed: Navigator.of(context, rootNavigator: true).pop,
                  child: Text('OK'),
                )
              ],
            ));
    final dir = await getTemporaryDirectory();
    var filename = '${dir.path}/image.jpeg';
    final base64 = base64Encode(frame.asUint8List());
    if (isButton) {
      downloadFile(frame.asUint8List(), 'jpeg');
    }
    _sendVideoAndFoto(base64, 'jpeg');
  }

  Future<void> downloadFile(Uint8List content, String mimeType) async {
    final dir = await getTemporaryDirectory();
    var filename = '${dir.path}/file.$mimeType';
    final file = File(filename);
    file.writeAsBytes(content);
    final params = SaveFileDialogParams(sourceFilePath: file.path);
    await FlutterFileDialog.saveFile(params: params);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          OrientationBuilder(
            builder: (context, orientation) {
              return Center(
                child: Container(
                  margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  decoration: BoxDecoration(color: Colors.black54),
                  child: RTCVideoView(_localRenderer, mirror: true),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.topRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 50,
                  child: PopupMenuButton<String>(
                    onSelected: _switchCamera,
                    icon: const Icon(Icons.flip_camera_ios_rounded),
                    color: Colors.tealAccent,
                    tooltip: "Selecionar Camera",
                    surfaceTintColor: Colors.white,
                    itemBuilder: (BuildContext context) {
                      if (_cameras != null) {
                        return _cameras!.map((device) {
                          return PopupMenuItem<String>(
                            value: device.deviceId,
                            child: Text(device.label),
                          );
                        }).toList();
                      } else {
                        print("Vazio");
                        return [];
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 100,
                  height: 50,
                  child: PopupMenuButton<String>(
                    onSelected: _selectVideoFps,
                    icon: const Icon(Icons.high_quality_outlined),
                    color: Colors.tealAccent,
                    tooltip: "Qualidade do video",
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem<String>(
                          value: _selectedVideoFPS,
                          child: Text('Select FPS ($_selectedVideoFPS)'),
                        ),
                        const PopupMenuDivider(),
                        ...['8', '15', '30', '60']
                            .map((fps) => PopupMenuItem<String>(
                                  value: fps,
                                  child: Text(fps),
                                ))
                            .toList()
                      ];
                    },
                  ),
                ),
                SizedBox(
                  width: 100,
                  height: 50,
                  child: PopupMenuButton<String>(
                    onSelected: _selectVideoSize,
                    icon: const Icon(Icons.screenshot_monitor),
                    color: Colors.tealAccent,
                    tooltip: "Resolução da camera",
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem<String>(
                          value: _selectedVideoSize.toString(),
                          child:
                              Text('Select Video Size ($_selectedVideoSize)'),
                        ),
                        const PopupMenuDivider(),
                        ...['320x240', '640x480', '1280x720', '1920x1080']
                            .map((fps) => PopupMenuItem<String>(
                                  value: fps,
                                  child: Text(fps),
                                ))
                            .toList()
                      ];
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                  ),
                  _inCalling
                      ? SizedBox(
                          width: 100,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent),
                            onPressed: () {
                              _captureFrame(true);
                              setState(() {});
                            },
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.tealAccent,
                            ),
                          ),
                        )
                      : const Text(""),
                  const SizedBox(
                    width: 20,
                  ),
                  _inCalling
                      ? SizedBox(
                          width: 100,
                          height: 50,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent),
                              onPressed:
                                  _isRec ? _stopRecording : _startRecording,
                              child: _isRec
                                  ? const Icon(Icons.stop, color: Colors.red)
                                  : const Icon(Icons.fiber_manual_record,
                                      color: Colors.red)),
                        )
                      : const Text(""),
                  SizedBox(
                    width: 100,
                    height: 50,
                    child: PopupMenuButton<MediaDeviceInfo>(
                      onSelected: (device) {
                        setState(() {
                          _selectedAudioDevice = device;
                        });
                        _switchMicrophone(device);
                      },
                      tooltip: "Selecionar Microfone",
                      icon: const Icon(Icons.mic_rounded),
                      color: Colors.tealAccent,
                      itemBuilder: (BuildContext context) {
                        return _audioDevices.map((device) {
                          return PopupMenuItem<MediaDeviceInfo>(
                            value: device,
                            child: Text(device.label),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _switchMicrophone(MediaDeviceInfo device) async {
    if (_localStream == null) return;

    await Helper.selectAudioOutput(device.deviceId);
    setState(() {});
  }

  void _switchCamera(String deviceId) async {
    if (_localStream == null) return;

    await Helper.switchCamera(
        _localStream!.getVideoTracks()[0], deviceId, _localStream);
    _localRenderer.srcObject = _localStream;
    setState(() {});
  }

  Future<void> fetchAudioDevices() async {
    try {
      MediaStream stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      List<MediaDeviceInfo> allDevices =
          await navigator.mediaDevices.enumerateDevices();
      List<MediaDeviceInfo> audioDevices =
          allDevices.where((device) => device.kind == 'audioinput').toList();

      setState(() {
        _audioDevices = audioDevices;
        _selectedAudioDevice =
            _audioDevices.isNotEmpty ? _audioDevices[0] : null;
      });

      await stream.dispose();
    } catch (e) {
      print('Error fetching audio devices: $e');
    }
  }
}
