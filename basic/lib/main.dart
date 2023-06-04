import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  runApp(BasicApplication());
}

class BasicApplication extends StatelessWidget {
  const BasicApplication({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late RTCPeerConnection alice;
  late RTCPeerConnection bob;

  MediaStream? mediaStream;


  late RTCVideoRenderer localRenderer;
  late RTCVideoRenderer remoteRenderer;

  final mediaConstraints = {
    'audio': false,
    'video': true,
  };

  @override
  void initState() {
    super.initState();


    localRenderer = RTCVideoRenderer();
    remoteRenderer = RTCVideoRenderer();

    initWebRTC();
  }

  Future<void> initWebRTC() async {
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();

      alice = await createPeerConnection({});
      bob = await createPeerConnection({});

      bob.onIceCandidate = (event) {
        if (event.candidate != null) {
          alice.addCandidate(event);
        }
      };

      alice.onIceCandidate = (event) {
        if (event.candidate != null) {
          bob.addCandidate(event);
        }
      };

      mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = mediaStream;

      mediaStream!.getTracks().forEach((element) {
        alice.addTrack(element,mediaStream!);
      });


      bob.onTrack = (track) {
        remoteRenderer.srcObject = track.streams.first;
      };

      final offer = await alice.createOffer();
      await alice.setLocalDescription(offer);
      // print('Alice local description set: ${offer.sdp}');
      await bob.setRemoteDescription(offer);
      // print('Bob remote description set: ${offer.sdp}');

      final answer = await bob.createAnswer();
      await bob.setLocalDescription(answer);
      // print('Bob local description set: ${answer.sdp}');
      await alice.setRemoteDescription(answer);
      // print('Alice remote description set: ${answer.sdp}');

    } catch (error) {
      print(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebRTC Page'),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                ),
                margin: EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: RTCVideoView(
                    remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    mirror: false,
                    placeholderBuilder: (BuildContext context) {
                      return Container(
                        color: Colors.grey,
                        child: Center(
                          child: Text('Waiting for remote video...'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                ),
                margin: EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: RTCVideoView(
                    localRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    placeholderBuilder: (BuildContext context) {
                      return Container(
                        color: Colors.grey,
                        child: Center(
                          child: Text('Waiting for local video...'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    localRenderer.dispose();
    remoteRenderer.dispose();
    alice.close();
    bob.close();
    super.dispose();
  }
}
