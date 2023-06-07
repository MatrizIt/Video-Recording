import 'dart:core';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

/*
 * getUserMedia sample
 */
class GetUserMediaSampleMobile extends StatefulWidget {
  static String tag = 'get_usermedia_sample';

  @override
  _GetUserMediaSampleMobileState createState() => _GetUserMediaSampleMobileState();
}

class _GetUserMediaSampleMobileState extends State<GetUserMediaSampleMobile> {
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  MediaRecorder? _mediaRecorder;
  bool get _isRec => _mediaRecorder != null;

  List<MediaDeviceInfo>? _mediaDevicesList;

  @override
  void initState() {
    super.initState();
    initRenderers();
    navigator.mediaDevices.ondevicechange = (event) async {
      print('++++++ ondevicechange ++++++');
      _mediaDevicesList = await navigator.mediaDevices.enumerateDevices();
    };
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

  void initRenderers() async {
    await _localRenderer.initialize();
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
    if (_localStream == null) throw Exception('Stream is not initialized');
    if (Platform.isIOS) {
      print('Recording is not available on iOS');
      return;
    }
    // TODO(rostopira): request write storage permission
    final storagePath = await getExternalStorageDirectory();
    if (storagePath == null) throw Exception('Can\'t find storagePath');

    final filePath = storagePath.path + '/webrtc_sample/test.mp4';
    _mediaRecorder = MediaRecorder();
    setState(() {});

    final videoTrack = _localStream!
        .getVideoTracks()
        .firstWhere((track) => track.kind == 'video');
    await _mediaRecorder!.start(
      filePath,
      videoTrack: videoTrack,
    );
  }

  void _stopRecording() async {
    await _mediaRecorder?.stop();
    setState(() {
      _mediaRecorder = null;
    });
  }


  void _toggleCamera() async {
    if (_localStream == null) throw Exception('Stream is not initialized');

    final videoTrack = _localStream!
        .getVideoTracks()
        .firstWhere((track) => track.kind == 'video');
    await Helper.switchCamera(videoTrack);
  }

  void _captureFrame() async {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 400,
                  height: 400,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,

                      child: RTCVideoView(_localRenderer, mirror: true),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 50,

                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))
                      ),
                      onPressed: _inCalling ? _hangUp : _makeCall,
                      child: _inCalling ? const Text("Encerrar video") : const Text("Iniciar video")),
                ),

                _inCalling ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.camera),
                        onPressed: _captureFrame,
                      ),
                      IconButton(
                        icon: Icon(_isRec ? Icons.stop : Icons.fiber_manual_record),
                        onPressed: _isRec ? _stopRecording : _startRecording,
                      ),
                    ],
                  ) : Text("")
                ],
            ),
          );
        },
      ),
    );
  }

  void _selectAudioOutput(String deviceId) {
    _localRenderer.audioOutput(deviceId);
  }
}
/*appBar: AppBar(
        title: Text('Teste da POC de video'),
        actions: _inCalling
            ? <Widget>[
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_off : Icons.flash_on),
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: Icon(Icons.switch_video),
            onPressed: _toggleCamera,
          ),
          IconButton(
            icon: Icon(Icons.camera),
            onPressed: _captureFrame,
          ),
          IconButton(
            icon: Icon(_isRec ? Icons.stop : Icons.fiber_manual_record),
            onPressed: _isRec ? _stopRecording : _startRecording,
          ),
          PopupMenuButton<String>(
            onSelected: _selectAudioOutput,
            itemBuilder: (BuildContext context) {
              if (_mediaDevicesList != null) {
                return _mediaDevicesList!
                    .where((device) => device.kind == 'audiooutput')
                    .map((device) {
                  return PopupMenuItem<String>(
                    value: device.deviceId,
                    child: Text(device.label),
                  );
                }).toList();
              }
              return [];
            },
          ),
        ]
            : null,
      ),



      floatingActionButton: FloatingActionButton(
        onPressed: _inCalling ? _hangUp : _makeCall,
        tooltip: _inCalling ? 'Hangup' : 'Call',
        child: Icon(_inCalling ? Icons.call_end : Icons.phone),
      ),




      */