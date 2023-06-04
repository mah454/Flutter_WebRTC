import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter WebRTC',
      home: const MyHomePage(title: 'WebRTC Tutorial'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  bool _offer = false;

  late RTCPeerConnection _peerConnection;
  late MediaStream _localStream;

  final TextEditingController candidateTextController = TextEditingController();

  final stunServers = {
    "iceServers": [
      {"url": "stun:192.168.1.123:3478"},
    ]
  };

  final sdpConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': []
  };

  @override
  void initState() {
    initRenderers();
    _createPeerConnection();
    super.initState();
  }

  void initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _createPeerConnection() async {
    _localStream = await _getUserMedia();

    _peerConnection = await createPeerConnection(stunServers, sdpConstraints);
    _peerConnection.addStream(_localStream);

    _peerConnection.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(
          jsonEncode({
            'candidate': e.candidate.toString(),
            'sdpMid': e.sdpMid.toString(),
            'sdpMLineIndex': e.sdpMLineIndex,
          }),
        );
      }
    };

    _peerConnection.onIceConnectionState = (e) {
      print(e);
    };

    _peerConnection.onAddStream = (stream) {
      print('addStream ${stream.id}');
      _remoteRenderer.srcObject = stream;
    };
  }

  _getUserMedia() async {
    final mediaConstraints = {
      'audio': true,
      'video': true,
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = stream;
    return stream;
  }

  void _createOffer() async {
    var sessionDescription = await _peerConnection.createOffer();
    var session = parse(sessionDescription.sdp!);
    print(jsonEncode(session));
    _offer = true;
    _peerConnection.setLocalDescription(sessionDescription);
  }

  void _setRemoteDescription() async {
    var jsonString = candidateTextController.text;
    dynamic session = await jsonDecode(jsonString);
    String sdp = write(session, null);
    var description = RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print(description.toMap());
    await _peerConnection.setRemoteDescription(description);
  }

  void _createAnswer() async {
    var description = await _peerConnection.createAnswer();
    var session = parse(description.sdp!);
    print(jsonEncode(session));
    _peerConnection.setLocalDescription(description);
  }

  void _setCandidate() async {
    var jsonString = candidateTextController.text;
    dynamic session = await jsonDecode(jsonString);
    print(session['candidate']);
    var candidate = RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection.addCandidate(candidate);
  }

  Row videoRenderers() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
            ),
            width: 300,
            height: 300,
            padding: EdgeInsets.all(10),
            child: RTCVideoView(
              _localRenderer,
              mirror: true,
              placeholderBuilder: (context) {
                return Container(
                  color: Colors.grey,
                  child: Center(
                    child: Text(
                      "Wait to local video ...",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 10,
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
            ),
            width: 300,
            height: 300,
            padding: EdgeInsets.all(10),
            child: RTCVideoView(
              _remoteRenderer,
              mirror: true,
              placeholderBuilder: (context) {
                return Container(
                  color: Colors.grey,
                  child: Center(
                    child: Text(
                      "Wait to remote video ...",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );

  Row controllerButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(onPressed: _createOffer, child: Text('Offer')),
          SizedBox(
            width: 10,
          ),
          ElevatedButton(onPressed: _createAnswer, child: Text('Answer')),
          SizedBox(
            width: 10,
          ),
          ElevatedButton(onPressed: _setRemoteDescription, child: Text('Set remote description')),
          SizedBox(
            width: 10,
          ),
          ElevatedButton(onPressed: _setCandidate, child: Text('Set candidate')),
        ],
      );

  Center sdpCandidateTextField() => Center(
        child: SizedBox(
          width: 400,
          child: TextField(
            decoration: InputDecoration(
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black))),
            controller: candidateTextController,
            maxLines: 4,
            maxLength: TextField.noMaxLength,
            keyboardType: TextInputType.multiline,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          videoRenderers(),
          SizedBox(
            height: 10,
          ),
          controllerButtons(),
          SizedBox(
            height: 10,
          ),
          sdpCandidateTextField(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    super.dispose();
  }
}
