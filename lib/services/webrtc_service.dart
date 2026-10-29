import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/turn_config.dart';

typedef SendRtcSignal = void Function(
  String type,
  Map<String, dynamic> payload,
);

enum ConnectionQuality { strong, medium, weak }

class AudioDevice {
  const AudioDevice({
    required this.id,
    required this.label,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final bool isDefault;
}

class WebRtcService {
  WebRtcService({this.onSpeakingChanged, this.onLocalSpeakingChanged});

  static const _speakingThreshold = 0.1;
  static const _speakingPollInterval = Duration(milliseconds: 700);

  void Function(Set<String> peerIds)? onSpeakingChanged;
  void Function(bool isSpeaking)? onLocalSpeakingChanged;
  TurnConfig? _turnServer;

  Map<String, dynamic> get _configuration => {
    'iceServers': <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      if (_turnServer case final turnServer?) ...[
        {
          'urls': turnServer.turnUrl,
          'username': turnServer.username,
          'credential': turnServer.password,
        },
      ],
    ],
  };

  final Map<String, RTCPeerConnection> _connections = {};
  final Map<String, SendRtcSignal> _sendSignals = {};
  final Map<String, Future<RTCPeerConnection>> _creatingConnections = {};
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};
  final Map<String, Set<MediaStream>> _remoteStreams = {};
  final Map<String, Set<MediaStreamTrack>> _remoteAudioTracks = {};
  final Map<String, double> _peerVolumes = {};
  final Map<String, double> _lastAudiblePeerVolumes = {};
  final Set<String> _speakingPeers = {};
  final Set<String> _reportedStatsErrors = {};
  Timer? _speakingTimer;
  bool _isPollingSpeaking = false;
  bool _isLocalSpeaking = false;
  bool _isDisposing = false;
  bool _isSwitchingAudioInput = false;
  bool _isHandlingDeviceChange = false;
  MediaStream? _localStream;
  bool _isMuted = false;
  String? _selectedInputDeviceId;
  String? _selectedOutputDeviceId;
  Timer? _deviceChangeDebounce;
  Set<String> _knownInputDeviceIds = {};
  Set<String> _knownOutputDeviceIds = {};

  bool get isMuted => _isMuted;
  bool get isLocalSpeaking => _isLocalSpeaking;
  String? get selectedInputDeviceId => _selectedInputDeviceId;
  String? get selectedOutputDeviceId => _selectedOutputDeviceId;
  double peerVolume(String peerId) => _peerVolumes[peerId] ?? 1;
  Iterable<String> get peerIds => {
    ..._connections.keys,
    ..._creatingConnections.keys,
  };

  Future<void> initializeAudio({
    TurnConfig? turnServer,
    String? inputDeviceId,
    String? outputDeviceId,
  }) async {
    _isDisposing = false;
    _turnServer = turnServer;
    if (_localStream != null) return;

    final inputs = await getAudioInputs();
    final availableInputId = _availableDeviceId(inputDeviceId, inputs);
    var activeInputId = availableInputId;
    late MediaStream stream;
    try {
      stream = await _openAudioStream(availableInputId);
    } catch (error, stackTrace) {
      if (availableInputId == null) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'Open Voice audio',
            context: ErrorDescription('while opening the default microphone'),
          ),
        );
        throw StateError('Microphone not found or access denied: $error');
      }
      debugPrint(
        'Saved microphone unavailable; falling back to default: $error',
      );
      stream = await _openAudioStream(null);
      activeInputId = null;
    }

    final audioTracks = stream.getAudioTracks();
    if (audioTracks.isEmpty) {
      await stream.dispose();
      final error = StateError('Microphone not found or access denied.');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          library: 'Open Voice audio',
          context: ErrorDescription('while validating the microphone track'),
        ),
      );
      throw error;
    }
    final localTrack = audioTracks.first;
    localTrack.enabled = true;
    debugPrint(
      'Local microphone track acquired: id=${localTrack.id}, '
      'enabled=${localTrack.enabled}',
    );
    _localStream = stream;
    await _ensureSpeakerphone(preferBluetooth: true);
    _selectedInputDeviceId = activeInputId;
    final outputs = await getAudioOutputs();
    _selectedOutputDeviceId = _availableDeviceId(outputDeviceId, outputs);
    try {
      await _routeAudioOutput(_selectedOutputDeviceId);
    } catch (error, stackTrace) {
      _selectedOutputDeviceId = null;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Open Voice audio',
          context: ErrorDescription(
            'while restoring the saved speaker device; using the system default',
          ),
        ),
      );
    }
    _knownInputDeviceIds = inputs.map((device) => device.id).toSet();
    _knownOutputDeviceIds = outputs.map((device) => device.id).toSet();
    navigator.mediaDevices.ondevicechange = (_) {
      _deviceChangeDebounce?.cancel();
      _deviceChangeDebounce = Timer(
        const Duration(milliseconds: 350),
        () => unawaited(_handleAudioDeviceChange()),
      );
    };
  }

  Future<void> _handleAudioDeviceChange() async {
    if (_isDisposing || _localStream == null || _isHandlingDeviceChange) {
      return;
    }
    if (_isSwitchingAudioInput) {
      _deviceChangeDebounce?.cancel();
      _deviceChangeDebounce = Timer(
        const Duration(milliseconds: 350),
        () => unawaited(_handleAudioDeviceChange()),
      );
      return;
    }
    _isHandlingDeviceChange = true;
    try {
      final inputs = await getAudioInputs();
      final outputs = await getAudioOutputs();
      final inputIds = inputs.map((device) => device.id).toSet();
      final outputIds = outputs.map((device) => device.id).toSet();
      final addedBluetoothInput = inputs
          .where(
            (device) =>
                !_knownInputDeviceIds.contains(device.id) &&
                _isBluetoothDevice(device),
          )
          .firstOrNull;
      final addedBluetoothOutput = outputs
          .where(
            (device) =>
                !_knownOutputDeviceIds.contains(device.id) &&
                _isBluetoothDevice(device),
          )
          .firstOrNull;

      final inputDeviceId =
          addedBluetoothInput?.id ??
          (_selectedInputDeviceId != null &&
                  inputIds.contains(_selectedInputDeviceId)
              ? _selectedInputDeviceId
              : null);
      if (_localStream != null) {
        await selectAudioInput(inputDeviceId);
      }

      if (addedBluetoothOutput != null) {
        await selectAudioOutput(addedBluetoothOutput.id);
      } else if (_selectedOutputDeviceId != null &&
          outputIds.contains(_selectedOutputDeviceId)) {
        await _routeAudioOutput(_selectedOutputDeviceId);
      } else {
        _selectedOutputDeviceId = null;
        if (!kIsWeb && Platform.isAndroid) {
          await Helper.setSpeakerphoneOnButPreferBluetooth();
        } else {
          await _ensureSpeakerphone(preferBluetooth: true);
        }
      }

      _knownInputDeviceIds = inputIds;
      _knownOutputDeviceIds = outputIds;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Open Voice audio',
          context: ErrorDescription(
            'while refreshing microphone and speaker routes after a device change',
          ),
        ),
      );
    } finally {
      _isHandlingDeviceChange = false;
    }
  }

  bool _isBluetoothDevice(AudioDevice device) => RegExp(
    r'bluetooth|wireless|earbuds|headset',
    caseSensitive: false,
  ).hasMatch('${device.id} ${device.label}');

  Future<List<AudioDevice>> getAudioInputs() async =>
      _enumerateAudioDevices('audioinput');

  Future<List<AudioDevice>> getAudioOutputs() async =>
      _enumerateAudioDevices('audiooutput');

  Future<List<AudioDevice>> _enumerateAudioDevices(String kind) async {
    final devices = await navigator.mediaDevices.enumerateDevices();
    final seenIds = <String>{};
    final seenLabels = <String>{};
    final matchingDevices = devices
        .where((device) => device.kind == kind)
        .toList(growable: false);
    String normalizeLabel(String label) {
      final normalized = label
          .replaceFirst(
            RegExp(r'^default(?:\s*[-:]\s*|\s+)', caseSensitive: false),
            '',
          )
          .trim();
      return normalized.toLowerCase() == 'default'
          ? ''
          : normalized.toLowerCase();
    }

    final defaultDevice = matchingDevices
        .where(
          (device) =>
              device.deviceId.trim().toLowerCase() == 'default' ||
              device.label.trim().toLowerCase() == 'default' ||
              device.label.trim().toLowerCase().startsWith('default -') ||
              device.label.trim().toLowerCase().startsWith('default:'),
        )
        .firstOrNull;
    final defaultLabel = defaultDevice == null
        ? null
        : normalizeLabel(defaultDevice.label);
    final results = <AudioDevice>[];
    for (final device in matchingDevices) {
      final id = device.deviceId.trim();
      final label = device.label.trim();
      final isDefaultEntry =
          id.toLowerCase() == 'default' ||
          label.toLowerCase() == 'default' ||
          label.toLowerCase().startsWith('default -') ||
          label.toLowerCase().startsWith('default:');
      if (isDefaultEntry || id.isEmpty || !seenIds.add(id)) {
        continue;
      }
      final normalizedLabel = normalizeLabel(label);
      if (kind == 'audioinput' &&
          (label.toLowerCase() == 'default' ||
              (normalizedLabel.isNotEmpty &&
                  !seenLabels.add(normalizedLabel)))) {
        continue;
      }
      results.add(
        AudioDevice(
          id: id,
          label: label.isEmpty
              ? (kind == 'audioinput' ? 'Microphone' : 'Speaker')
              : label,
          isDefault:
              defaultLabel != null &&
              normalizedLabel == defaultLabel &&
              normalizedLabel.isNotEmpty,
        ),
      );
    }

    if (results.isNotEmpty && !results.any((device) => device.isDefault)) {
      results[0] = AudioDevice(
        id: results[0].id,
        label: results[0].label,
        isDefault: true,
      );
    }
    return List.unmodifiable(results);
  }

  String? _availableDeviceId(String? deviceId, List<AudioDevice> devices) {
    if (deviceId == null || deviceId.isEmpty) return null;
    if (devices.isEmpty || devices.any((device) => device.id == deviceId)) {
      return deviceId;
    }
    return null;
  }

  Future<MediaStream> _openAudioStream(String? deviceId) =>
      navigator.mediaDevices.getUserMedia({
        'audio': deviceId == null ? true : {'deviceId': deviceId},
        'video': false,
      });

  Future<void> selectAudioInput(String? deviceId) async {
    final oldStream = _localStream;
    if (oldStream == null) {
      throw StateError('Audio has not been initialized.');
    }
    if (_isSwitchingAudioInput) {
      throw StateError('A microphone switch is already in progress.');
    }
    _isSwitchingAudioInput = true;
    try {
      await _selectAudioInput(deviceId, oldStream);
    } finally {
      _isSwitchingAudioInput = false;
    }
  }

  Future<void> _selectAudioInput(
    String? deviceId,
    MediaStream oldStream,
  ) async {
    final inputs = await getAudioInputs();
    final availableInputId = _availableDeviceId(deviceId, inputs);
    final oldTracks = oldStream.getAudioTracks();
    if (oldTracks.isEmpty) {
      throw StateError('The current microphone track is unavailable.');
    }
    if (!kIsWeb && Platform.isAndroid) {
      await Helper.setMicrophoneMute(true, oldTracks.first);
    }
    for (final track in oldTracks) {
      await track.stop();
    }

    for (final entry in _connections.entries) {
      final senders = (await entry.value.getSenders())
          .where((sender) => sender.track?.kind == 'audio')
          .toList();
      for (final sender in senders) {
        final removed = await entry.value.removeTrack(sender);
        if (!removed) {
          throw StateError(
            'Could not remove the previous microphone from a peer connection.',
          );
        }
      }
    }
    for (final track in oldStream.getTracks()) {
      if (track.kind != 'audio') await track.stop();
    }
    await oldStream.dispose();
    _localStream = null;

    late final MediaStream newStream;
    var activeInputId = availableInputId;
    try {
      newStream = await _openAudioStreamWithTrack(availableInputId);
    } catch (error, stackTrace) {
      debugPrint(
        'Could not open selected microphone; falling back to default: '
        '$error\n$stackTrace',
      );
      if (availableInputId == null) {
        Error.throwWithStackTrace(
          StateError('Could not open the default microphone: $error'),
          stackTrace,
        );
      }
      newStream = await _openAudioStreamWithTrack(null);
      activeInputId = null;
    }

    final newTrack = newStream.getAudioTracks().first..enabled = !_isMuted;
    _localStream = newStream;
    _selectedInputDeviceId = activeInputId;
    Object? switchError;
    StackTrace? switchStackTrace;
    var microphoneMuteApplied = false;
    for (final connection in _connections.entries) {
      try {
        await connection.value.addTrack(newTrack, newStream);
        if (!microphoneMuteApplied && !kIsWeb && Platform.isAndroid) {
          await Helper.setMicrophoneMute(_isMuted, newTrack);
          microphoneMuteApplied = true;
        }
        await _renegotiate(connection.key, connection.value);
      } catch (error, stackTrace) {
        switchError ??= error;
        switchStackTrace ??= stackTrace;
      }
    }
    if (switchError != null) {
      Error.throwWithStackTrace(switchError, switchStackTrace!);
    }
  }

  Future<void> _renegotiate(String peerId, RTCPeerConnection connection) async {
    final sendSignal = _sendSignals[peerId];
    if (sendSignal == null) {
      throw StateError('No signaling route is available for $peerId.');
    }
    final offer = await connection.createOffer();
    await connection.setLocalDescription(offer);
    sendSignal('offer', offer.toMap().cast<String, dynamic>());
  }

  Future<MediaStream> _openAudioStreamWithTrack(String? deviceId) async {
    final stream = await _openAudioStream(deviceId);
    if (stream.getAudioTracks().isEmpty) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
      throw StateError('The selected microphone has no audio track.');
    }
    return stream;
  }

  Future<void> _routeAudioOutput(String? deviceId) async {
    if (deviceId != null && deviceId.isNotEmpty) {
      await Helper.selectAudioOutput(deviceId);
    } else if (Platform.isAndroid) {
      await Helper.clearAndroidCommunicationDevice();
    } else if (Platform.isWindows) {
      // flutter_webrtc does not expose a Windows output reset API. Leaving
      // the device unselected keeps playback on the OS default route.
      return;
    } else if (Platform.isIOS) {
      await Helper.setSpeakerphoneOn(true);
    }
  }

  Future<void> selectAudioOutput(String? deviceId) async {
    final outputs = await getAudioOutputs();
    final availableOutputId = _availableDeviceId(deviceId, outputs);
    await _routeAudioOutput(availableOutputId);
    _selectedOutputDeviceId = availableOutputId;
  }

  Future<void> setMuted(bool muted) async {
    final stream = _localStream;
    if (stream == null) {
      throw StateError('Audio has not been initialized.');
    }
    final audioTracks = stream.getAudioTracks();
    if (audioTracks.isEmpty) {
      throw StateError('No local audio track is available.');
    }

    final track = audioTracks.first;
    track.enabled = !muted;
    _isMuted = muted;
  }

  Future<void> createOffer(String peerId, SendRtcSignal sendSignal) async {
    final connection = await _getOrCreateConnection(peerId, sendSignal);
    final offer = await connection.createOffer();
    await connection.setLocalDescription(offer);
    sendSignal('offer', offer.toMap().cast<String, dynamic>());
  }

  Future<void> handleOffer(
    String peerId,
    Map<String, dynamic> payload,
    SendRtcSignal sendSignal,
  ) async {
    final connection = await _getOrCreateConnection(peerId, sendSignal);
    final description = _readDescription(payload);
    await connection.setRemoteDescription(description);
    await _addPendingCandidates(peerId, connection);

    final answer = await connection.createAnswer();
    await connection.setLocalDescription(answer);
    sendSignal('answer', answer.toMap().cast<String, dynamic>());
  }

  Future<void> handleAnswer(
    String peerId,
    Map<String, dynamic> payload,
    SendRtcSignal sendSignal,
  ) async {
    final connection = await _getOrCreateConnection(peerId, sendSignal);
    await connection.setRemoteDescription(_readDescription(payload));
    await _addPendingCandidates(peerId, connection);
  }

  Future<void> handleCandidate(
    String peerId,
    Map<String, dynamic> payload,
    SendRtcSignal sendSignal,
  ) async {
    final candidate = _readCandidate(payload);
    final connection = _connections[peerId];
    if (connection == null || await connection.getRemoteDescription() == null) {
      _pendingCandidates.putIfAbsent(peerId, () => []).add(candidate);
      return;
    }
    await connection.addCandidate(candidate);
  }

  Future<void> setPeerVolume(String peerId, double volume) async {
    if (!volume.isFinite) {
      throw ArgumentError.value(volume, 'volume', 'Must be a finite number.');
    }
    final normalizedVolume = volume.clamp(0.0, 2.0).toDouble();
    final tracks = _remoteAudioTracks[peerId] ?? const <MediaStreamTrack>{};
    for (final track in tracks) {
      await Helper.setVolume(normalizedVolume, track);
    }
    _peerVolumes[peerId] = normalizedVolume;
    if (normalizedVolume > 0) {
      _lastAudiblePeerVolumes[peerId] = normalizedVolume;
    }
  }

  Future<double> togglePeerMute(String peerId) async {
    final volume = peerVolume(peerId);
    final targetVolume = volume == 0
        ? (_lastAudiblePeerVolumes[peerId] ?? 1)
        : 0.0;
    await setPeerVolume(peerId, targetVolume);
    return targetVolume;
  }

  Future<void> removePeer(String peerId) async {
    if (_isDisposing) return;
    _pendingCandidates.remove(peerId);
    final creation = _creatingConnections[peerId];
    if (creation != null) {
      try {
        await creation;
      } catch (_) {
        // The connection factory reports the original error to its caller.
      }
    }
    _pendingCandidates.remove(peerId);
    _reportedStatsErrors.remove(peerId);
    _remoteStreams.remove(peerId);
    _remoteAudioTracks.remove(peerId);
    _sendSignals.remove(peerId);
    if (_speakingPeers.remove(peerId)) {
      onSpeakingChanged?.call(Set.unmodifiable(_speakingPeers));
    }
    final connection = _connections.remove(peerId);
    if (connection == null) {
      _stopSpeakingPollIfIdle();
      return;
    }
    Object? cleanupError;
    StackTrace? cleanupStackTrace;
    try {
      await connection.close();
    } catch (error, stackTrace) {
      cleanupError = error;
      cleanupStackTrace = stackTrace;
    }
    try {
      await connection.dispose();
    } catch (error, stackTrace) {
      cleanupError ??= error;
      cleanupStackTrace ??= stackTrace;
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError, cleanupStackTrace!);
    }
  }

  Future<void> dispose() async {
    if (_isDisposing) return;
    _isDisposing = true;
    _deviceChangeDebounce?.cancel();
    _deviceChangeDebounce = null;
    navigator.mediaDevices.ondevicechange = null;
    _knownInputDeviceIds.clear();
    _knownOutputDeviceIds.clear();
    Object? cleanupError;
    StackTrace? cleanupStackTrace;
    _speakingTimer?.cancel();
    _speakingTimer = null;

    for (final creation in _creatingConnections.values.toList()) {
      try {
        await creation;
      } catch (error, stackTrace) {
        cleanupError ??= error;
        cleanupStackTrace ??= stackTrace;
      }
    }

    final stream = _localStream;
    _localStream = null;
    _turnServer = null;
    _isMuted = false;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        try {
          await track.stop();
        } catch (error, stackTrace) {
          cleanupError ??= error;
          cleanupStackTrace ??= stackTrace;
        }
      }
      try {
        await stream.dispose();
      } catch (error, stackTrace) {
        cleanupError ??= error;
        cleanupStackTrace ??= stackTrace;
      }
    }

    final connections = _connections.values.toList();
    _connections.clear();
    _sendSignals.clear();
    _creatingConnections.clear();
    _pendingCandidates.clear();
    _remoteStreams.clear();
    _remoteAudioTracks.clear();
    _peerVolumes.clear();
    _lastAudiblePeerVolumes.clear();
    _speakingPeers.clear();
    _isLocalSpeaking = false;
    onLocalSpeakingChanged?.call(false);
    _reportedStatsErrors.clear();
    onSpeakingChanged?.call(const {});
    for (final connection in connections) {
      try {
        await connection.close();
      } catch (error, stackTrace) {
        cleanupError ??= error;
        cleanupStackTrace ??= stackTrace;
      }
      try {
        await connection.dispose();
      } catch (error, stackTrace) {
        cleanupError ??= error;
        cleanupStackTrace ??= stackTrace;
      }
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError, cleanupStackTrace!);
    }
  }

  Future<RTCPeerConnection> _getOrCreateConnection(
    String peerId,
    SendRtcSignal sendSignal,
  ) async {
    if (_isDisposing) {
      throw StateError('Audio resources are being disposed.');
    }
    _sendSignals[peerId] = sendSignal;
    final existing = _connections[peerId];
    if (existing != null) return existing;
    final pending = _creatingConnections[peerId];
    if (pending != null) return pending;

    final stream = _localStream;
    if (stream == null) {
      throw StateError('Audio must be initialized before negotiating a peer.');
    }

    final creation = _createConnection(peerId, stream, sendSignal);
    _creatingConnections[peerId] = creation;
    try {
      return await creation;
    } finally {
      if (identical(_creatingConnections[peerId], creation)) {
        _creatingConnections.remove(peerId);
      }
    }
  }

  Future<RTCPeerConnection> _createConnection(
    String peerId,
    MediaStream stream,
    SendRtcSignal sendSignal,
  ) async {
    final connection = await createPeerConnection(_configuration);
    try {
      connection.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        sendSignal('candidate', candidate.toMap().cast<String, dynamic>());
      };
      connection.onTrack = (event) {
        final streams = _remoteStreams.putIfAbsent(
          peerId,
          () => <MediaStream>{},
        );
        streams.addAll(event.streams);
        if (event.track.kind == 'audio') {
          _remoteAudioTracks
              .putIfAbsent(peerId, () => <MediaStreamTrack>{})
              .add(event.track);
          unawaited(_applyPeerVolume(peerId, event.track));
        }
        unawaited(_routeRemoteAudioToSpeaker());
      };
      connection.onConnectionState = (state) {
        if (!_isDisposing &&
            (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                state == RTCPeerConnectionState.RTCPeerConnectionStateClosed)) {
          unawaited(removePeer(peerId));
        }
      };
      for (final track in stream.getAudioTracks()) {
        debugPrint(
          'Adding local ${track.kind} track to peer $peerId: '
          'enabled=${track.enabled}, muted=${track.muted}',
        );
        final sender = await connection.addTrack(track, stream);
        if (sender.track == null) {
          throw StateError(
            'Local microphone track was not attached to $peerId.',
          );
        }
      }
      _connections[peerId] = connection;
      await _ensureSpeakerphone(preferBluetooth: true);
      _startSpeakingPoll();
    } catch (error) {
      await connection.close();
      await connection.dispose();
      rethrow;
    }
    return connection;
  }

  Future<void> _applyPeerVolume(String peerId, MediaStreamTrack track) async {
    try {
      await Helper.setVolume(peerVolume(peerId), track);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Open Voice audio',
          context: ErrorDescription(
            'while setting the volume for peer $peerId',
          ),
        ),
      );
    }
  }

  void _startSpeakingPoll() {
    _speakingTimer ??= Timer.periodic(
      _speakingPollInterval,
      (_) => unawaited(_pollSpeakingLevels()),
    );
  }

  void _stopSpeakingPollIfIdle() {
    if (_connections.isNotEmpty || _creatingConnections.isNotEmpty) return;
    _speakingTimer?.cancel();
    _speakingTimer = null;
  }

  Future<void> _pollSpeakingLevels() async {
    if (_isDisposing || _isPollingSpeaking) return;
    _isPollingSpeaking = true;
    try {
      var isLocalSpeaking = false;
      for (final entry in _connections.entries.toList()) {
        try {
          final reports = await entry.value.getStats();
          if (_isDisposing ||
              !identical(_connections[entry.key], entry.value)) {
            continue;
          }
          final isSpeaking = reports.any((report) {
            if (report.type != 'inbound-rtp') return false;
            final kind = report.values['kind'] ?? report.values['mediaType'];
            if (kind != null && kind != 'audio') return false;
            return _hasSpeakingAudioLevel(report);
          });
          _setPeerSpeaking(entry.key, isSpeaking);
          if (reports.any(_hasLocalSpeakingAudioLevel)) {
            isLocalSpeaking = true;
          }
        } catch (error, stackTrace) {
          if (_reportedStatsErrors.add(entry.key)) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'Open Voice audio',
                context: ErrorDescription(
                  'while checking speaking activity for ${entry.key}',
                ),
              ),
            );
          }
          _setPeerSpeaking(entry.key, false);
        }
      }
      _setLocalSpeaking(isLocalSpeaking);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Open Voice audio',
          context: ErrorDescription('while polling remote speaking activity'),
        ),
      );
    } finally {
      _isPollingSpeaking = false;
    }
  }

  bool _hasSpeakingAudioLevel(StatsReport report) {
    final level = report.values['audioLevel'];
    return level is num && level > _speakingThreshold;
  }

  bool _hasLocalSpeakingAudioLevel(StatsReport report) {
    if (report.type != 'media-source' && report.type != 'outbound-rtp') {
      return false;
    }
    final kind = report.values['kind'] ?? report.values['mediaType'];
    if (kind != null && kind != 'audio') return false;
    return _hasSpeakingAudioLevel(report);
  }

  void _setLocalSpeaking(bool isSpeaking) {
    if (_isLocalSpeaking == isSpeaking) return;
    _isLocalSpeaking = isSpeaking;
    onLocalSpeakingChanged?.call(isSpeaking);
  }

  Future<ConnectionQuality> getConnectionQuality(String peerId) async {
    final connection = _connections[peerId];
    if (connection == null || _isDisposing) return ConnectionQuality.weak;

    final reports = await connection.getStats();
    double? roundTripTimeSeconds;
    var packetsLost = 0;
    var packetsReceived = 0;
    for (final report in reports) {
      if (report.type == 'candidate-pair' &&
          (report.values['selected'] == true ||
              report.values['nominated'] == true)) {
        final roundTripTime = report.values['currentRoundTripTime'];
        if (roundTripTime is num) {
          roundTripTimeSeconds = roundTripTime.toDouble();
        }
      } else if (report.type == 'inbound-rtp') {
        final kind = report.values['kind'] ?? report.values['mediaType'];
        if (kind != null && kind != 'audio') continue;
        final lost = report.values['packetsLost'];
        final received = report.values['packetsReceived'];
        if (lost is num && lost > 0) packetsLost += lost.toInt();
        if (received is num && received > 0) {
          packetsReceived += received.toInt();
        }
      }
    }

    final totalPackets = packetsLost + packetsReceived;
    final packetLoss = totalPackets > 0 ? packetsLost / totalPackets : 0.0;
    if (roundTripTimeSeconds == null && totalPackets == 0) {
      return ConnectionQuality.medium;
    }
    if ((roundTripTimeSeconds != null && roundTripTimeSeconds >= 0.4) ||
        packetLoss >= 0.05) {
      return ConnectionQuality.weak;
    }
    if ((roundTripTimeSeconds != null && roundTripTimeSeconds >= 0.15) ||
        packetLoss >= 0.01) {
      return ConnectionQuality.medium;
    }
    return ConnectionQuality.strong;
  }

  void _setPeerSpeaking(String peerId, bool isSpeaking) {
    final changed = isSpeaking
        ? _speakingPeers.add(peerId)
        : _speakingPeers.remove(peerId);
    if (changed) onSpeakingChanged?.call(Set.unmodifiable(_speakingPeers));
  }

  Future<void> _routeRemoteAudioToSpeaker() async {
    try {
      await _ensureSpeakerphone(preferBluetooth: true);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Open Voice audio',
          context: ErrorDescription('while routing remote audio to speakers'),
        ),
      );
    }
  }

  Future<void> _ensureSpeakerphone({bool preferBluetooth = false}) async {
    if (!kIsWeb && Platform.isAndroid) {
      if (preferBluetooth) {
        await Helper.setSpeakerphoneOnButPreferBluetooth();
      } else {
        await Helper.setSpeakerphoneOn(true);
      }
    } else if (Platform.isIOS) {
      await Helper.setSpeakerphoneOn(true);
    }
  }

  Future<void> _addPendingCandidates(
    String peerId,
    RTCPeerConnection connection,
  ) async {
    final candidates = _pendingCandidates.remove(peerId);
    if (candidates == null) return;
    for (final candidate in candidates) {
      await connection.addCandidate(candidate);
    }
  }

  RTCSessionDescription _readDescription(Map<String, dynamic> payload) {
    final sdp = payload['sdp'];
    final type = payload['type'];
    if (sdp is! String || type is! String) {
      throw const FormatException('Invalid WebRTC session description.');
    }
    return RTCSessionDescription(sdp, type);
  }

  RTCIceCandidate _readCandidate(Map<String, dynamic> payload) {
    final candidate = payload['candidate'];
    final sdpMid = payload['sdpMid'];
    final sdpMLineIndex = payload['sdpMLineIndex'];
    if (candidate is! String ||
        (sdpMid != null && sdpMid is! String) ||
        (sdpMLineIndex != null && sdpMLineIndex is! int)) {
      throw const FormatException('Invalid ICE candidate.');
    }
    return RTCIceCandidate(candidate, sdpMid as String?, sdpMLineIndex as int?);
  }
}
