import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'supabase_service.dart';

class WebRTCService {
  final String roomId;
  final String opponentId;
  final Function(MediaStream? stream) onRemoteStreamUpdate;
  final Function(String status) onConnectionStateChange;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isMicMuted = false;
  final List<RTCIceCandidate> _iceCandidateQueue = [];

  bool get isMicMuted => _isMicMuted;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  final Map<String, dynamic> _iceConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  WebRTCService({
    required this.roomId,
    required this.opponentId,
    required this.onRemoteStreamUpdate,
    required this.onConnectionStateChange,
  });

  /// 1. Initialize local microphone audio track
  Future<void> initAudio() async {
    try {
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': false,
      };
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      debugPrint('[WebRTCService] Local microphone track acquired.');
    } catch (e) {
      debugPrint('[WebRTCService] Error obtaining local audio: $e');
      rethrow;
    }
  }

  /// 2. Initialize Peer Connection
  Future<void> initializePeerConnection() async {
    if (_localStream == null) await initAudio();

    try {
      _peerConnection = await createPeerConnection(_iceConfiguration);

      // Listen to connection changes
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[WebRTCService] Connection state: $state');
        onConnectionStateChange(state.name);
      };

      // Send local ICE candidates to opponent
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          debugPrint('[WebRTCService] Local ICE Candidate generated.');
          SupabaseService.sendSignaling(
            roomId: roomId,
            receiverId: opponentId,
            type: 'candidate',
            payload: {
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
              'candidate': candidate.candidate,
            },
          );
        }
      };

      // Add local audio stream to track
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Capture remote incoming track
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          debugPrint('[WebRTCService] Remote audio track received!');
          _remoteStream = event.streams[0];
          onRemoteStreamUpdate(_remoteStream);
        }
      };
    } catch (e) {
      debugPrint('[WebRTCService] Error creating peer connection: $e');
    }
  }

  /// 3. Initiate call (starts offer-answer exchange)
  Future<void> startCall() async {
    if (_peerConnection == null) await initializePeerConnection();

    try {
      RTCSessionDescription offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });

      await _peerConnection!.setLocalDescription(offer);
      debugPrint('[WebRTCService] Local SDP Offer set.');

      await SupabaseService.sendSignaling(
        roomId: roomId,
        receiverId: opponentId,
        type: 'offer',
        payload: {'sdp': offer.sdp, 'type': offer.type},
      );
    } catch (e) {
      debugPrint('[WebRTCService] Error creating WebRTC offer: $e');
    }
  }

  /// 4. Process incoming signaling messages from Supabase
  Future<void> handleSignaling(Map<String, dynamic> signal) async {
    final type = signal['type'] as String;
    final payload = signal['payload'] as Map<String, dynamic>;

    if (_peerConnection == null) await initializePeerConnection();

    try {
      if (type == 'offer') {
        debugPrint('[WebRTCService] Incoming offer received. Answering...');
        final sdp = payload['sdp'] as String;
        final offerDesc = RTCSessionDescription(sdp, 'offer');
        await _peerConnection!.setRemoteDescription(offerDesc);

        // Process queued ICE candidates
        for (final cand in _iceCandidateQueue) {
          debugPrint('[WebRTCService] Applying queued ICE candidate.');
          await _peerConnection!.addCandidate(cand);
        }
        _iceCandidateQueue.clear();

        final answer = await _peerConnection!.createAnswer({
          'offerToReceiveAudio': 1,
          'offerToReceiveVideo': 0,
        });
        await _peerConnection!.setLocalDescription(answer);

        await SupabaseService.sendSignaling(
          roomId: roomId,
          receiverId: opponentId,
          type: 'answer',
          payload: {'sdp': answer.sdp, 'type': answer.type},
        );
      } else if (type == 'answer') {
        debugPrint('[WebRTCService] Incoming answer received.');
        final sdp = payload['sdp'] as String;
        final answerDesc = RTCSessionDescription(sdp, 'answer');
        await _peerConnection!.setRemoteDescription(answerDesc);

        // Process queued ICE candidates
        for (final cand in _iceCandidateQueue) {
          debugPrint('[WebRTCService] Applying queued ICE candidate.');
          await _peerConnection!.addCandidate(cand);
        }
        _iceCandidateQueue.clear();
      } else if (type == 'candidate') {
        debugPrint('[WebRTCService] Incoming candidate received.');
        final candidate = RTCIceCandidate(
          payload['candidate'] as String,
          payload['sdpMid'] as String?,
          payload['sdpMLineIndex'] as int?,
        );
        
        final remoteDesc = await _peerConnection!.getRemoteDescription();
        if (remoteDesc == null) {
          debugPrint('[WebRTCService] Remote description is null. Queueing ICE candidate.');
          _iceCandidateQueue.add(candidate);
        } else {
          await _peerConnection!.addCandidate(candidate);
        }
      }
    } catch (e) {
      debugPrint('[WebRTCService] Signaling process exception: $e');
    }
  }

  /// 5. Mute/Unmute microphone
  void toggleMute() {
    if (_localStream != null) {
      _isMicMuted = !_isMicMuted;
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !_isMicMuted;
      });
      debugPrint('[WebRTCService] Microphone muted: $_isMicMuted');
    }
  }

  /// 6. Close the connection and release tracks
  Future<void> close() async {
    try {
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      await _localStream?.dispose();
      await _peerConnection?.close();
      await _peerConnection?.dispose();
      
      _localStream = null;
      _peerConnection = null;
      _remoteStream = null;
      debugPrint('[WebRTCService] Voice session closed successfully.');
    } catch (e) {
      debugPrint('[WebRTCService] Error during close: $e');
    }
  }
}
