// ignore: uri_does_not_exist
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:html' as webFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import '../constants/video_size.dart';


/*
 * getUserMedia sample
 */
class GetUserMediaSample extends StatefulWidget {
  String? id;
  String? description;

  GetUserMediaSample(this.id, this.description);

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
  final player = AudioPlayer();
  bool _logEvents = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = '';
  String lastError = '';
  String lastStatus = '';
  String? _selectedVideoFPS = '30';
  VideoSize _selectedVideoSize = VideoSize(1280, 720);
  String? _selectedVideoInputId;
  List<MediaDeviceInfo>? _cameras;
  List<MediaDeviceInfo> _audioDevices = [];
  MediaDeviceInfo? _selectedAudioDevice;
  AudioPlayer audioPlayer = AudioPlayer();
  var senders = <RTCRtpSender>[];
  double selectedBrightness = 0.5;
  bool isSucess = true;
  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  var text = "";

  @override
  void initState() {
    super.initState();
    initRenderers();
    loadDevices();
    navigator.mediaDevices.ondevicechange = (event) {
      loadDevices();
    };
    _makeCall();
    _listen();

    navigator.mediaDevices.enumerateDevices().then((md) {
      setState(() {
        cameras = md.where((d) => d.kind == 'videoinput').toList();
      });
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
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



  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('Status: $status');
          if (status == 'done') {
            _speech.stop();
          }else if(status == 'notListening'){
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

  void onResultSpeech (result) {
    SpeechRecognitionWords resultados = result.alternates[result.alternates.length - 1];
    print("Result --> ${resultados.recognizedWords} + ${resultados.confidence}");
    if(resultados.confidence > 0.1){
      if (result.alternates[result.alternates.length - 1].toString().contains("pause")) {
        _hangUp();
      } else if (result.alternates[result.alternates.length - 1].toString().contains("foto")) {
        _captureFrame(false);
      } else if (result.alternates[result.alternates.length - 1].toString().contains("gravar")) {
        _startRecording();
      } else if (result.alternates[result.alternates.length - 1].toString().contains("parar")) {
        _stopRecording();
      }
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
      fetchAudioDevices();
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
      _inCalling = false;
    });
  }

  void _startRecording() async {

    if (_localStream == null) throw Exception('Can\'t record without a stream');
    _mediaRecorder = MediaRecorder();
    setState(() {});
    _mediaRecorder?.startWeb(_localStream!);
  }

  void _stopRecording() async {

    final objectUrl = await _mediaRecorder?.stop();

    http.Response response = await http.get(Uri.parse(objectUrl));
    if (response.statusCode == 200) {
      Uint8List bytes = response.bodyBytes;
      String base64String = base64.encode(bytes);

      _sendVideoAndFoto(base64String, ".mp4");
    }
    /*
    print("Result --> ${res.statusCode}");*/
    /*webFile.AnchorElement(
      href: objectUrl,
    )
      ..setAttribute("download", "${objectUrl.split('/')[3]}.mp4")
      ..click();*/

    setState(() {
      _mediaRecorder = null;
    });
  }

  void _sendVideoAndFoto(String base64String, String mimeType) async {
    try {
      DateTime data = DateTime.now();

      var token = ((data.day + data.month + data.year) * data.day);
      var tokenToString = token.toString();

      List<int> uint = utf8.encode(tokenToString);

      String token64 = base64.encode(uint);
      int id = int.parse(widget.id!);

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

  void _captureFrame(bool buttonClick) async {

    if (_localStream == null) throw Exception('Can\'t record without a stream');
    final videoTrack = _localStream!
        .getVideoTracks()
        .firstWhere((track) => track.kind == 'video');

    final frame = await videoTrack.captureFrame();
    if (kIsWeb) {
      var blob = webFile.Blob([frame.asUint8List()], "image/jpeg", "native");
      var text = widget.description;

      addTextToImage(blob, text!, buttonClick);

      if (isSucess == true) {
        await player.setAsset('assets/player/foto-player.mp3');
        player.play();
      } else if (isSucess == false) {
        await player.setAsset('assets/player/erro.mp3');
        player.play();
      }
    }
  }

  void addTextToImage(webFile.Blob blob, String text, bool buttonClick) {
    final reader = webFile.FileReader();
    reader.readAsDataUrl(blob);

    reader.onLoadEnd.listen((event) {
      final base64DataUrl = reader.result as String?;
      if (base64DataUrl != null) {
        final base64String = base64DataUrl.split(',').last;

        final imageElement = webFile.ImageElement();
        imageElement.src = base64DataUrl;

        imageElement.onLoad.listen((_) async {
          final canvas = webFile.CanvasElement(
              width: imageElement.width!, height: imageElement.height!);
          final context =
              canvas.getContext('2d') as webFile.CanvasRenderingContext2D;

          context.drawImage(imageElement, 0, 0);

          context.font = '20px Arial';
          context.fillStyle = '#ffffff';
          context.fillText(text, 10, 30);

          final modifiedDataUrl = canvas.toDataUrl('image/jpeg');
          final modifiedBase64 = modifiedDataUrl.split(',').last;
          final modifiedBase64String =
              base64.encode(base64.decode(modifiedBase64));

          final modifiedBlob =
              webFile.Blob([base64.decode(modifiedBase64String)], 'image/jpeg');

          if (buttonClick == true) {
            final downloadLink = webFile.AnchorElement()
              ..href = webFile.Url.createObjectUrlFromBlob(modifiedBlob)
              ..setAttribute('download', 'image_with_text.jpeg')
              ..click();

            webFile.Url.revokeObjectUrl(downloadLink.href!);
          }

           _sendVideoAndFoto(modifiedBase64String, ".jpeg");
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: RTCVideoView(_localRenderer, mirror: true),
        ),
        Align(
            alignment: Alignment.topCenter,
            child: Text(
              "Id > ${widget.id} Description ${widget.description}",
              style: const TextStyle(
                  color: Colors.teal, decoration: TextDecoration.none),
            )),
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
                /*_inCalling
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
                    : const Text(""),*/
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
                              _isRec ? _stopRecording : _startRecording;
                            },
                            child: _isRec
                                ? const Icon(Icons.stop, color: Colors.red)
                                : const Icon(Icons.fiber_manual_record,
                                    color: Colors.red)),
                      )
                    : const Text(""),
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
                        return [];
                      }
                    },
                  ),
                ),
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
        )
      ],
    );
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

  void _switchMicrophone(MediaDeviceInfo device) async {
    // Implement your logic to switch the microphone device here
    // You can use the selected device information (device) to switch the microphone
    print('Switching microphone to device: ${device.label}');
  }
}
