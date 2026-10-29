import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../l10n/app_localizations.dart';
import '../models/turn_config.dart';
import 'app_settings.dart';
import 'sound_effects_service.dart';
import 'system_notification_service.dart';
import 'webrtc_service.dart';

enum PeerRole { moderator, participant }

class RoomPeer {
  const RoomPeer({
    required this.id,
    required this.name,
    required this.role,
    this.quality = ConnectionQuality.medium,
    this.isConnected = true,
  });

  final String id;
  final String name;
  final PeerRole role;
  final ConnectionQuality quality;
  final bool isConnected;

  RoomPeer copyWith({ConnectionQuality? quality, bool? isConnected}) =>
      RoomPeer(
        id: id,
        name: name,
        role: role,
        quality: quality ?? this.quality,
        isConnected: isConnected ?? this.isConnected,
      );

  factory RoomPeer.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    return RoomPeer(
      id: json['id'] as String,
      name: json['name'] as String,
      role: role == 'moderator' ? PeerRole.moderator : PeerRole.participant,
      quality: ConnectionQuality.values.firstWhere(
        (quality) => quality.name == json['quality'],
        orElse: () => ConnectionQuality.medium,
      ),
      isConnected: json['isConnected'] is bool
          ? json['isConnected'] as bool
          : true,
    );
  }
}

class JoinRequest {
  const JoinRequest({required this.id, required this.name});

  final String id;
  final String name;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isHistorical = false,
  });

  final String id;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isHistorical;

  Map<String, dynamic> toJson() => {
    'type': 'chat_message',
    'id': id,
    'senderName': senderName,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    bool isHistorical = false,
  }) {
    final id = json['id'];
    final senderName = json['senderName'];
    final text = json['text'];
    final timestamp = json['timestamp'];
    if (id is! String ||
        id.isEmpty ||
        senderName is! String ||
        senderName.isEmpty ||
        text is! String ||
        text.isEmpty ||
        text.length > 2000 ||
        timestamp is! String) {
      throw const FormatException('Invalid chat message.');
    }
    final parsedTimestamp = DateTime.tryParse(timestamp);
    if (parsedTimestamp == null) {
      throw const FormatException('Invalid chat message timestamp.');
    }
    return ChatMessage(
      id: id,
      senderName: senderName,
      text: text,
      timestamp: parsedTimestamp,
      isHistorical: isHistorical,
    );
  }
}

class SignalingException implements Exception {
  const SignalingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SignalingService extends ChangeNotifier {
  SignalingService({
    required SoundEffectsService soundEffects,
    required SystemNotificationService notifications,
    required AppSettings appSettings,
  }) : _soundEffects = soundEffects,
       _notifications = notifications,
       _appSettings = appSettings {
    _webRtcService.onSpeakingChanged = _handleSpeakingChanged;
    _webRtcService.onLocalSpeakingChanged = _handleLocalSpeakingChanged;
  }

  static const _hostPeerId = 'host';
  static const _connectionTimeout = Duration(seconds: 5);
  static const _reconnectionWindow = Duration(seconds: 20);
  static const _qualityReportingInterval = Duration(seconds: 3);

  HttpServer? _server;
  WebSocketChannel? _clientChannel;
  StreamSubscription<dynamic>? _clientSubscription;
  final Map<WebSocketChannel, RoomPeer> _connectedPeers = {};
  final Map<WebSocketChannel, JoinRequest> _pendingJoinRequests = {};
  final Map<String, RoomPeer> _disconnectedPeers = {};
  final Map<String, Timer> _disconnectedPeerTimers = {};
  final Map<String, String> _reconnectTokensByPeerId = {};
  final Set<String> _pendingPeerNotifications = {};
  final WebRtcService _webRtcService = WebRtcService();
  final SoundEffectsService _soundEffects;
  final SystemNotificationService _notifications;
  final AppSettings _appSettings;

  List<RoomPeer> _peers = const [];
  List<RoomPeer> get peers => List.unmodifiable(_peers);
  final List<ChatMessage> _chatMessages = [];
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  String get localDisplayName =>
      _isHost ? _hostDisplayName : _clientDisplayName ?? '';
  List<JoinRequest> get pendingJoinRequests =>
      List.unmodifiable(_pendingJoinRequests.values);

  String? _localIp;
  String? get localIp => _localIp;

  String? _hostIp;
  String? get hostIp => _hostIp;

  int? _port;
  int? get port => _port;

  bool _isHost = false;
  bool get isHost => _isHost;

  bool get isInRoom =>
      _server != null || _clientChannel != null || _isReconnecting;
  bool get isMuted => _webRtcService.isMuted;
  String? get selectedInputDeviceId => _webRtcService.selectedInputDeviceId;
  String? get selectedOutputDeviceId => _webRtcService.selectedOutputDeviceId;
  bool get isReconnecting => _isReconnecting;
  bool get reconnectionFailed => _reconnectionFailed;
  Set<String> _speakingPeerIds = const {};
  Set<String> get speakingPeerIds => _speakingPeerIds;
  String? get localPeerId => _isHost ? _hostPeerId : _clientPeerId;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  bool _roomClosed = false;
  bool get roomClosed => _roomClosed;
  bool _roomKicked = false;
  bool get roomKicked => _roomKicked;
  bool _isWaitingForApproval = false;
  bool get isWaitingForApproval => _isWaitingForApproval;
  bool _joinApproved = false;
  bool get joinApproved => _joinApproved;
  bool _joinRejected = false;
  bool get joinRejected => _joinRejected;

  int _peerSequence = 0;
  int _requestSequence = 0;
  int _chatSequence = 0;
  String? _clientPeerId;
  String? _clientDisplayName;
  TurnConfig? _pendingTurnServer;
  String _hostDisplayName = 'Host';
  bool _disposed = false;
  bool _isClosingRoom = false;
  bool _isLeavingRoom = false;
  bool _isReconnecting = false;
  bool _reconnectionFailed = false;
  String? _clientReconnectToken;
  Timer? _reconnectDeadlineTimer;
  Timer? _qualityReportTimer;
  Completer<bool>? _reconnectAttempt;

  Future<void> startHosting(
    int port, {
    required String displayName,
    TurnConfig? turnServer,
  }) async {
    await leaveRoom();
    _isHost = true;
    _hostDisplayName = displayName;
    _port = port;
    _errorMessage = null;
    _roomClosed = false;
    _roomKicked = false;

    try {
      await _webRtcService.initializeAudio(
        turnServer: turnServer,
        inputDeviceId: _appSettings.audioInputDeviceId,
        outputDeviceId: _appSettings.audioOutputDeviceId,
      );
      _localIp = await _findLocalIp();
      _setPeers([
        RoomPeer(
          id: _hostPeerId,
          name: _hostDisplayName,
          role: PeerRole.moderator,
          quality: ConnectionQuality.strong,
        ),
      ]);
      final socketHandler = webSocketHandler(
        _handleHostConnection,
        pingInterval: const Duration(seconds: 15),
      );
      final handler = const Pipeline().addHandler((request) {
        if (request.url.path != 'ws') {
          return Response.notFound('Not found');
        }
        return socketHandler(request);
      });
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
      await _soundEffects.play('join');
      notifyListeners();
    } catch (error) {
      await _webRtcService.dispose();
      _isHost = false;
      _localIp = null;
      _port = null;
      _setPeers(const []);
      _setError('Could not start the room server: $error');
      rethrow;
    }
  }

  Future<void> joinRoom({
    required String hostIp,
    required int port,
    required String displayName,
    TurnConfig? turnServer,
  }) async {
    await leaveRoom();
    _isHost = false;
    _hostIp = hostIp;
    _port = port;
    _clientDisplayName = displayName;
    _errorMessage = null;
    _roomClosed = false;
    _roomKicked = false;
    _setPeers(const []);

    _pendingTurnServer = turnServer;
    _isWaitingForApproval = false;
    _joinApproved = false;
    _joinRejected = false;
    _isLeavingRoom = false;
    _isReconnecting = false;
    _reconnectionFailed = false;
    _clientReconnectToken = null;

    final channel = WebSocketChannel.connect(
      Uri(scheme: 'ws', host: hostIp, port: port, path: '/ws'),
    );
    _clientChannel = channel;
    try {
      await channel.ready.timeout(_connectionTimeout);
      _listenToClientChannel(channel);
      channel.sink.add(
        jsonEncode({'type': 'join_request', 'name': displayName}),
      );
      _isWaitingForApproval = true;
      notifyListeners();
    } catch (error) {
      _clientChannel = null;
      try {
        await channel.sink.close().timeout(const Duration(seconds: 1));
      } catch (cleanupError, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: cleanupError,
            stack: stackTrace,
            library: 'Open Voice signaling',
            context: ErrorDescription('while cancelling a failed connection'),
          ),
        );
      }
      final message = error is TimeoutException
          ? 'Connection failed: Room not found or invalid IP.'
          : 'Connection failed: Room not found or invalid IP. ($error)';
      _hostIp = null;
      _port = null;
      _pendingTurnServer = null;
      _isWaitingForApproval = false;
      _setError(message);
      throw SignalingException(message);
    }
  }

  void _listenToClientChannel(WebSocketChannel channel) {
    _clientSubscription = channel.stream.listen(
      (message) => unawaited(_handleClientMessage(message)),
      onError: (Object error, StackTrace stackTrace) {
        unawaited(
          _handleClientDisconnect(
            'Connection to the host was interrupted: $error',
            channel: channel,
          ),
        );
      },
      onDone: () {
        unawaited(
          _handleClientDisconnect(
            'The connection to the host was closed.',
            channel: channel,
          ),
        );
      },
    );
  }

  void _completeReconnectAttempt(bool result) {
    final attempt = _reconnectAttempt;
    if (attempt != null && !attempt.isCompleted) {
      attempt.complete(result);
    }
  }

  void _markReconnectFailed() {
    if (!_isReconnecting || _isLeavingRoom || _disposed) return;
    _reconnectDeadlineTimer?.cancel();
    _reconnectDeadlineTimer = null;
    _isReconnecting = false;
    _reconnectionFailed = true;
    _completeReconnectAttempt(false);
    _reconnectAttempt = null;
    notifyListeners();
  }

  Future<void> _attemptReconnectUntilDeadline() async {
    final deadline = DateTime.now().add(_reconnectionWindow);
    while (_isReconnecting &&
        !_isLeavingRoom &&
        !_disposed &&
        DateTime.now().isBefore(deadline)) {
      final token = _clientReconnectToken;
      final hostIp = _hostIp;
      final port = _port;
      final name = _clientDisplayName;
      if (token == null || hostIp == null || port == null || name == null) {
        break;
      }

      final channel = WebSocketChannel.connect(
        Uri(scheme: 'ws', host: hostIp, port: port, path: '/ws'),
      );
      _clientChannel = channel;
      try {
        await channel.ready.timeout(const Duration(seconds: 3));
        _listenToClientChannel(channel);
        final attempt = Completer<bool>();
        _reconnectAttempt = attempt;
        channel.sink.add(
          jsonEncode({
            'type': 'reconnect_request',
            'token': token,
            'name': name,
          }),
        );
        final restored = await attempt.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () => false,
        );
        _reconnectAttempt = null;
        if (restored) return;
      } catch (error, stackTrace) {
        debugPrint('Reconnect attempt failed: $error\n$stackTrace');
        _completeReconnectAttempt(false);
        _reconnectAttempt = null;
      }

      if (identical(_clientChannel, channel)) {
        _clientChannel = null;
        final subscription = _clientSubscription;
        _clientSubscription = null;
        try {
          await subscription?.cancel();
        } catch (error, stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'Open Voice signaling',
              context: ErrorDescription(
                'while closing an unsuccessful reconnect attempt',
              ),
            ),
          );
        }
        try {
          await channel.sink.close(WebSocketStatus.goingAway);
        } catch (error, stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'Open Voice signaling',
              context: ErrorDescription(
                'while closing an unsuccessful reconnect socket',
              ),
            ),
          );
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    _markReconnectFailed();
  }

  Future<void> cancelJoinRequest() async {
    if (_isHost) return;
    final channel = _clientChannel;
    if (channel == null) return;

    channel.sink.add(
      jsonEncode({'type': 'cancel_request', 'name': _clientDisplayName}),
    );
    _clientChannel = null;
    final subscription = _clientSubscription;
    _clientSubscription = null;
    Object? cleanupError;
    StackTrace? cleanupStackTrace;

    try {
      await channel.sink
          .close(WebSocketStatus.normalClosure)
          .timeout(const Duration(seconds: 2));
    } catch (error, stackTrace) {
      cleanupError = error;
      cleanupStackTrace = stackTrace;
    }
    try {
      await subscription?.cancel();
    } catch (error, stackTrace) {
      cleanupError ??= error;
      cleanupStackTrace ??= stackTrace;
    }

    _isWaitingForApproval = false;
    _joinRejected = false;
    _pendingTurnServer = null;
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError, cleanupStackTrace!);
    }
  }

  Future<void> approveJoinRequest(String requestId) async {
    final entry = _pendingJoinRequests.entries
        .where((entry) => entry.value.id == requestId)
        .firstOrNull;
    if (entry == null) return;

    final channel = entry.key;
    final request = entry.value;
    _pendingJoinRequests.remove(channel);
    final newPeer = RoomPeer(
      id: 'peer-${++_peerSequence}',
      name: request.name,
      role: PeerRole.participant,
    );
    final reconnectToken = _createReconnectToken();
    _reconnectTokensByPeerId[newPeer.id] = reconnectToken;

    _connectedPeers[channel] = newPeer;
    channel.sink.add(
      jsonEncode({
        'type': 'approve_join',
        'peerId': newPeer.id,
        'name': newPeer.name,
        'reconnectToken': reconnectToken,
      }),
    );
    _broadcastPeerList();
    _pendingPeerNotifications.add(newPeer.id);
    _broadcastSound('join');
    notifyListeners();
  }

  String _uniquePeerName(String requestedName) {
    final activeNames = {
      _hostDisplayName.toLowerCase(),
      ..._connectedPeers.values.map((peer) => peer.name.toLowerCase()),
      ..._disconnectedPeers.values.map((peer) => peer.name.toLowerCase()),
      ..._pendingJoinRequests.values.map(
        (request) => request.name.toLowerCase(),
      ),
    };
    if (!activeNames.contains(requestedName.toLowerCase())) {
      return requestedName;
    }

    var suffix = 2;
    while (activeNames.contains('$requestedName $suffix'.toLowerCase())) {
      suffix++;
    }
    return '$requestedName $suffix';
  }

  String _createReconnectToken() {
    final random = math.Random.secure();
    return List<String>.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> rejectJoinRequest(String requestId) async {
    final entry = _pendingJoinRequests.entries
        .where((entry) => entry.value.id == requestId)
        .firstOrNull;
    if (entry == null) return;

    _pendingJoinRequests.remove(entry.key);
    try {
      entry.key.sink.add(jsonEncode({'type': 'reject_join'}));
      await entry.key.sink.close(WebSocketStatus.normalClosure);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Open Voice signaling',
          context: ErrorDescription('while rejecting a room join request'),
        ),
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> leaveRoom() async {
    _isLeavingRoom = true;
    _isReconnecting = false;
    _reconnectDeadlineTimer?.cancel();
    _reconnectDeadlineTimer = null;
    _qualityReportTimer?.cancel();
    _qualityReportTimer = null;
    _completeReconnectAttempt(false);
    _reconnectAttempt = null;
    _reconnectAttempt = null;
    final shouldPlayHostLeaveSound = _isHost && _server != null;
    if (shouldPlayHostLeaveSound) {
      await _soundEffects.play('leave');
    }
    final activeClientChannel = _clientChannel;
    final shouldPlayClientLeaveSound =
        activeClientChannel != null &&
        !_isHost &&
        _joinApproved &&
        !_isWaitingForApproval;
    if (activeClientChannel != null && shouldPlayClientLeaveSound) {
      activeClientChannel.sink.add(jsonEncode({'type': 'leave_room'}));
    }

    Object? cleanupError;
    StackTrace? cleanupStackTrace;
    void recordCleanupError(Object error, StackTrace stackTrace) {
      cleanupError ??= error;
      cleanupStackTrace ??= stackTrace;
    }

    final server = _server;
    _server = null;
    if (server != null) {
      _isClosingRoom = true;
      final channels = _connectedPeers.keys.toList();
      channels.addAll(_pendingJoinRequests.keys);
      final roomClosedMessage = jsonEncode({'type': 'room_closed'});
      for (final channel in channels) {
        try {
          channel.sink.add(roomClosedMessage);
        } catch (error, stackTrace) {
          _reportRoomShutdownError(error, stackTrace);
        }
      }
      for (final channel in channels) {
        try {
          await channel.sink
              .close(WebSocketStatus.normalClosure)
              .timeout(const Duration(seconds: 2));
        } catch (error, stackTrace) {
          _reportRoomShutdownError(error, stackTrace);
        }
      }
      _connectedPeers.clear();
      _pendingJoinRequests.clear();
      for (final timer in _disconnectedPeerTimers.values) {
        timer.cancel();
      }
      _disconnectedPeerTimers.clear();
      _disconnectedPeers.clear();
      _reconnectTokensByPeerId.clear();
      _pendingPeerNotifications.clear();
      try {
        await server.close(force: true).timeout(const Duration(seconds: 2));
      } catch (error, stackTrace) {
        _reportRoomShutdownError(error, stackTrace);
      }
    }

    try {
      await _webRtcService.dispose();
    } catch (error, stackTrace) {
      recordCleanupError(error, stackTrace);
    }

    final subscription = _clientSubscription;
    _clientSubscription = null;
    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (error, stackTrace) {
        recordCleanupError(error, stackTrace);
      }
    }

    final clientChannel = _clientChannel;
    _clientChannel = null;
    if (clientChannel != null) {
      try {
        if (shouldPlayClientLeaveSound &&
            identical(clientChannel, activeClientChannel)) {
          await _soundEffects.play('leave');
        }
        await clientChannel.sink.close(WebSocketStatus.goingAway);
      } catch (error, stackTrace) {
        recordCleanupError(error, stackTrace);
      }
    }

    _isHost = false;
    _localIp = null;
    _hostIp = null;
    _port = null;
    _clientPeerId = null;
    _clientDisplayName = null;
    _pendingTurnServer = null;
    _hostDisplayName = 'Host';
    _errorMessage = null;
    _roomClosed = false;
    _isClosingRoom = false;
    _isLeavingRoom = false;
    _isReconnecting = false;
    _reconnectionFailed = false;
    _clientReconnectToken = null;
    _isWaitingForApproval = false;
    _joinApproved = false;
    _joinRejected = false;
    _pendingJoinRequests.clear();
    _speakingPeerIds = const {};
    _connectedPeers.clear();
    _chatMessages.clear();
    _setPeers(const []);
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError!, cleanupStackTrace!);
    }
  }

  Future<String> _findLocalIp() async {
    final wifiIp = await NetworkInfo().getWifiIP();
    if (wifiIp != null && wifiIp.isNotEmpty) return wifiIp;

    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback && !address.isLinkLocal) {
          return address.address;
        }
      }
    }

    throw const SignalingException(
      'No local IPv4 address is available. Connect to a network and try again.',
    );
  }

  void _handleHostConnection(WebSocketChannel channel, String? protocol) {
    RoomPeer? peer;
    channel.stream.listen(
      (message) => unawaited(
        _handleHostMessage(
          channel,
          message,
          () => peer,
          (assignedPeer) => peer = assignedPeer,
        ),
      ),
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_removeHostPeer(channel));
      },
      onDone: () {
        unawaited(_removeHostPeer(channel));
      },
    );
  }

  Future<void> _handleHostMessage(
    WebSocketChannel channel,
    dynamic message,
    RoomPeer? Function() getPeer,
    void Function(RoomPeer) assignPeer,
  ) async {
    try {
      if (message is! String) {
        _sendProtocolError(channel, 'Messages must be JSON text.');
        return;
      }

      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) {
        _sendProtocolError(channel, 'Expected a JSON object.');
        return;
      }

      var peer = getPeer() ?? _connectedPeers[channel];
      if (peer != null) assignPeer(peer);
      if (decoded['type'] == 'cancel_request') {
        final request = _pendingJoinRequests.remove(channel);
        if (request != null) {
          notifyListeners();
        }
        await channel.sink.close(WebSocketStatus.normalClosure);
        return;
      }
      if (decoded['type'] == 'leave_room') {
        _pendingJoinRequests.remove(channel);
        await _removeHostPeer(channel, allowReconnect: false);
        await channel.sink.close(WebSocketStatus.normalClosure);
        return;
      }

      if (peer == null && decoded['type'] == 'reconnect_request') {
        final token = decoded['token'];
        if (token is! String || token.isEmpty) {
          _sendProtocolError(channel, 'Invalid reconnect credentials.');
          await channel.sink.close(WebSocketStatus.normalClosure);
          return;
        }
        final matchingPeerId = _reconnectTokensByPeerId.entries
            .where((entry) => entry.value == token)
            .map((entry) => entry.key)
            .firstOrNull;
        final returningPeer = matchingPeerId == null
            ? null
            : _disconnectedPeers.remove(matchingPeerId);
        if (matchingPeerId == null || returningPeer == null) {
          _sendProtocolError(channel, 'The reconnect window has expired.');
          await channel.sink.close(WebSocketStatus.normalClosure);
          return;
        }

        _disconnectedPeerTimers.remove(matchingPeerId)?.cancel();
        peer = returningPeer.copyWith(
          quality: ConnectionQuality.medium,
          isConnected: true,
        );
        _connectedPeers[channel] = peer;
        _pendingPeerNotifications.add(peer.id);
        assignPeer(peer);
        channel.sink.add(
          jsonEncode({
            'type': 'approve_join',
            'peerId': peer.id,
            'name': peer.name,
            'reconnectToken': token,
            'reconnected': true,
          }),
        );
        _broadcastPeerList();
        notifyListeners();
        return;
      }

      if (peer == null) {
        if (decoded['type'] != 'join_request') {
          _sendProtocolError(channel, 'Expected a join_request message.');
          return;
        }

        final requestedName = decoded['name'];
        final name = requestedName is String ? requestedName.trim() : '';
        if (name.isEmpty || name.length > 40) {
          _sendProtocolError(
            channel,
            'Name must be between 1 and 40 characters.',
          );
          return;
        }

        final request = JoinRequest(
          id: 'request-${++_requestSequence}',
          name: _uniquePeerName(name),
        );
        _pendingJoinRequests[channel] = request;
        notifyListeners();
        unawaited(_showJoinRequestNotification(request.name));
        return;
      }

      final type = decoded['type'];
      if (type == 'quality_report') {
        final qualityName = decoded['quality'];
        final quality = ConnectionQuality.values
            .where((value) => value.name == qualityName)
            .firstOrNull;
        if (quality == null) {
          _sendProtocolError(channel, 'Invalid connection quality report.');
          return;
        }
        _connectedPeers[channel] = peer.copyWith(quality: quality);
        _broadcastPeerList();
        return;
      }
      if (type == 'chat_message') {
        final senderName = decoded['senderName'];
        final textValue = decoded['text'];
        final timestampValue = decoded['timestamp'];
        final idValue = decoded['id'];
        if (senderName is! String ||
            senderName.trim().isEmpty ||
            textValue is! String ||
            textValue.trim().isEmpty ||
            textValue.length > 2000 ||
            timestampValue is! String ||
            idValue is! String ||
            !idValue.startsWith('${peer.id}:')) {
          _sendProtocolError(channel, 'Invalid chat message.');
          return;
        }
        final timestamp = DateTime.tryParse(timestampValue);
        if (timestamp == null) {
          _sendProtocolError(channel, 'Invalid chat message timestamp.');
          return;
        }
        final chatMessage = ChatMessage(
          id: idValue,
          senderName: peer.name,
          text: textValue.trim(),
          timestamp: timestamp,
        );
        _addChatMessage(chatMessage);
        final broadcast = jsonEncode(chatMessage.toJson());
        for (final recipient in _connectedPeers.keys.toList()) {
          try {
            recipient.sink.add(broadcast);
          } catch (error, stackTrace) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'Open Voice chat',
                context: ErrorDescription(
                  'while broadcasting a chat message to room members',
                ),
              ),
            );
          }
        }
        return;
      }
      if (type == 'approval_ready') {
        for (final chatMessage in _chatMessages) {
          final historyPayload = chatMessage.toJson()..['history'] = true;
          channel.sink.add(jsonEncode(historyPayload));
        }
        channel.sink.add(jsonEncode({'type': 'joined', 'peerId': peer.id}));
        unawaited(_createOfferToChannel(channel, peer.id));
        if (_pendingPeerNotifications.remove(peer.id)) {
          for (final entry in _connectedPeers.entries) {
            if (entry.key == channel) continue;
            entry.key.sink.add(
              jsonEncode({'type': 'peer_joined', 'peer': _peerToJson(peer)}),
            );
            channel.sink.add(
              jsonEncode({
                'type': 'peer_joined',
                'peer': _peerToJson(entry.value),
              }),
            );
          }
        }
        return;
      }
      if (type != 'offer' && type != 'answer' && type != 'candidate') {
        _sendProtocolError(channel, 'Unsupported signaling message.');
        return;
      }

      final targetId = decoded['to'];
      final payload = decoded['payload'];
      if (targetId is! String || payload is! Map<String, dynamic>) {
        _sendProtocolError(channel, 'Invalid signaling message.');
        return;
      }

      if (targetId == _hostPeerId) {
        await _handleHostRtcSignal(peer, type, payload, channel);
        return;
      }

      final target = _connectedPeers.entries
          .where((entry) => entry.value.id == targetId)
          .firstOrNull;
      if (target == null) {
        _sendProtocolError(
          channel,
          'The destination peer is no longer in the room.',
        );
        return;
      }

      target.key.sink.add(
        jsonEncode({'type': type, 'from': peer.id, 'payload': payload}),
      );
    } on FormatException {
      _sendProtocolError(channel, 'Invalid JSON message.');
    } catch (error) {
      final peer = getPeer();
      _setError('Signaling failed: $error');
      if (peer != null) {
        _sendProtocolError(channel, 'Signaling failed: $error');
      }
    }
  }

  Future<void> _handleHostRtcSignal(
    RoomPeer peer,
    String type,
    Map<String, dynamic> payload,
    WebSocketChannel channel,
  ) async {
    try {
      void sendSignal(String responseType, Map<String, dynamic> data) {
        channel.sink.add(
          jsonEncode({
            'type': responseType,
            'from': _hostPeerId,
            'payload': data,
          }),
        );
      }

      switch (type) {
        case 'offer':
          await _webRtcService.handleOffer(peer.id, payload, sendSignal);
          break;
        case 'answer':
          await _webRtcService.handleAnswer(peer.id, payload, sendSignal);
          break;
        case 'candidate':
          await _webRtcService.handleCandidate(peer.id, payload, sendSignal);
          break;
      }
    } catch (error) {
      _sendProtocolError(channel, 'WebRTC negotiation failed: $error');
    }
  }

  Future<void> _createOfferToChannel(
    WebSocketChannel channel,
    String peerId,
  ) async {
    try {
      await _webRtcService.createOffer(
        peerId,
        (type, payload) => channel.sink.add(
          jsonEncode({'type': type, 'from': _hostPeerId, 'payload': payload}),
        ),
      );
    } catch (error) {
      _setError('Could not start audio with $peerId: $error');
      _sendProtocolError(channel, 'Could not start audio: $error');
    }
  }

  Future<void> _removeHostPeer(
    WebSocketChannel channel, {
    bool allowReconnect = true,
  }) async {
    final pendingRequest = _pendingJoinRequests.remove(channel);
    if (pendingRequest != null) {
      if (!_isClosingRoom) notifyListeners();
      return;
    }

    final peer = _connectedPeers.remove(channel);
    if (peer == null) return;
    _pendingPeerNotifications.remove(peer.id);
    final reconnectToken = _reconnectTokensByPeerId[peer.id];
    if (!_isClosingRoom && allowReconnect && reconnectToken != null) {
      _disconnectedPeers[peer.id] = peer.copyWith(
        quality: ConnectionQuality.weak,
        isConnected: false,
      );
      _broadcastPeerList();
      _disconnectedPeerTimers.remove(peer.id)?.cancel();
      _disconnectedPeerTimers[peer.id] = Timer(_reconnectionWindow, () {
        _disconnectedPeerTimers.remove(peer.id);
        _disconnectedPeers.remove(peer.id);
        _reconnectTokensByPeerId.remove(peer.id);
        _pendingPeerNotifications.remove(peer.id);
        if (_isClosingRoom) return;
        _broadcastPeerList();
        _broadcastSound('leave');
      });
    } else {
      _disconnectedPeerTimers.remove(peer.id)?.cancel();
      _disconnectedPeers.remove(peer.id);
      _reconnectTokensByPeerId.remove(peer.id);
      _pendingPeerNotifications.remove(peer.id);
      if (!_isClosingRoom) {
        _broadcastPeerList();
        _broadcastSound('leave');
      }
    }
    try {
      await _webRtcService.removePeer(peer.id);
    } catch (error) {
      _setError('Could not release audio for ${peer.name}: $error');
    }
  }

  Future<void> kickPeer(String peerId) async {
    final entry = _connectedPeers.entries
        .where((entry) => entry.value.id == peerId)
        .firstOrNull;
    if (entry == null) return;

    final channel = entry.key;
    final peer = entry.value;
    _connectedPeers.remove(channel);
    _disconnectedPeerTimers.remove(peer.id)?.cancel();
    _disconnectedPeers.remove(peer.id);
    _reconnectTokensByPeerId.remove(peer.id);
    _pendingPeerNotifications.remove(peer.id);
    _broadcastSound('leave');
    try {
      channel.sink.add(jsonEncode({'type': 'kick_user'}));
    } catch (error, stackTrace) {
      _reportKickError(error, stackTrace, peer.name);
    }

    _broadcastPeerList();
    try {
      await _webRtcService.removePeer(peer.id);
    } catch (error, stackTrace) {
      _reportKickError(error, stackTrace, peer.name);
    }
    try {
      await channel.sink.close(WebSocketStatus.normalClosure);
    } catch (error, stackTrace) {
      _reportKickError(error, stackTrace, peer.name);
    }
  }

  void _reportKickError(Object error, StackTrace stackTrace, String peerName) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Open Voice signaling',
        context: ErrorDescription('while removing $peerName from the room'),
      ),
    );
  }

  Future<void> _handleClientMessage(dynamic message) async {
    if (message is! String) {
      _setError('The host sent an unsupported message.');
      return;
    }

    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) {
        _setError('The host sent an invalid message.');
        return;
      }

      switch (decoded['type']) {
        case 'room_closed':
          await _handleRoomClosed();
          break;
        case 'kick_user':
          await _handleKickedFromRoom();
          break;
        case 'approve_join':
          final peerId = decoded['peerId'];
          final assignedName = decoded['name'];
          final reconnectToken = decoded['reconnectToken'];
          if (peerId is! String ||
              peerId.isEmpty ||
              assignedName is! String ||
              assignedName.isEmpty ||
              reconnectToken is! String ||
              reconnectToken.isEmpty) {
            _setError('The host sent an invalid room assignment.');
            _completeReconnectAttempt(false);
            return;
          }
          try {
            await _webRtcService.initializeAudio(
              turnServer: _pendingTurnServer,
              inputDeviceId: _appSettings.audioInputDeviceId,
              outputDeviceId: _appSettings.audioOutputDeviceId,
            );
            _isWaitingForApproval = false;
            _joinApproved = true;
            _clientPeerId = peerId;
            _clientDisplayName = assignedName;
            _clientReconnectToken = reconnectToken;
            _peers = _peers
                .map(
                  (peer) => peer.id == peerId
                      ? RoomPeer(
                          id: peer.id,
                          name: assignedName,
                          role: peer.role,
                          quality: peer.quality,
                          isConnected: peer.isConnected,
                        )
                      : peer,
                )
                .toList();
            _clientChannel?.sink.add(jsonEncode({'type': 'approval_ready'}));
            if (_isReconnecting) {
              _isReconnecting = false;
              _reconnectionFailed = false;
              _reconnectDeadlineTimer?.cancel();
              _reconnectDeadlineTimer = null;
              _completeReconnectAttempt(true);
              _reconnectAttempt = null;
              _errorMessage = null;
            } else {
              unawaited(_showJoinAcceptedNotification(_hostIp ?? 'the room'));
            }
            _startQualityReporting();
            notifyListeners();
          } catch (error) {
            if (_isReconnecting) {
              _completeReconnectAttempt(false);
              return;
            }
            _setError('Could not access the microphone: $error');
            await cancelJoinRequest();
          }
          break;
        case 'play_sound':
          final sound = decoded['sound'];
          if (sound is! String || (sound != 'join' && sound != 'leave')) {
            _setError('The host sent an unsupported room sound.');
            return;
          }
          await _soundEffects.play(sound);
          break;
        case 'reject_join':
          _joinRejected = true;
          unawaited(_showJoinRejectedNotification());
          final channel = _clientChannel;
          try {
            await channel?.sink
                .close(WebSocketStatus.normalClosure)
                .timeout(const Duration(seconds: 2));
            if (identical(_clientChannel, channel)) _clientChannel = null;
          } catch (error, stackTrace) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'Open Voice signaling',
                context: ErrorDescription(
                  'while closing the rejected join connection',
                ),
              ),
            );
          }
          _isWaitingForApproval = false;
          notifyListeners();
          break;
        case 'joined':
          final peerId = decoded['peerId'];
          if (peerId is! String || peerId.isEmpty) {
            _setError('The host sent an invalid room assignment.');
            return;
          }
          _clientPeerId = peerId;
          break;
        case 'peer_list':
          final items = decoded['peers'];
          if (items is! List ||
              items.any((item) => item is! Map<String, dynamic>)) {
            _setError('The host sent an invalid peer list.');
            return;
          }
          final peers = items
              .cast<Map<String, dynamic>>()
              .map(RoomPeer.fromJson)
              .map(
                (peer) => peer.id == _clientPeerId && _clientDisplayName != null
                    ? RoomPeer(
                        id: peer.id,
                        name: _clientDisplayName!,
                        role: peer.role,
                        quality: peer.quality,
                        isConnected: peer.isConnected,
                      )
                    : peer,
              )
              .toList();
          _setPeers(peers);
          final peerIds = peers
              .map((peer) => peer.id)
              .where((id) => id != _clientPeerId)
              .toSet();
          for (final remoteId in _webRtcService.peerIds.toList()) {
            if (!peerIds.contains(remoteId)) {
              await _webRtcService.removePeer(remoteId);
            }
          }
          break;
        case 'peer_joined':
          final peer = decoded['peer'];
          if (peer is! Map<String, dynamic> ||
              peer['id'] is! String ||
              peer['id'] == _clientPeerId) {
            _setError('The host sent an invalid peer notification.');
            return;
          }
          await _sendClientOffer(peer['id'] as String);
          break;
        case 'chat_message':
          try {
            _addChatMessage(
              ChatMessage.fromJson(
                decoded,
                isHistorical: decoded['history'] == true,
              ),
            );
          } on FormatException catch (error) {
            _setError('The host sent an invalid chat message: $error');
          }
          break;
        case 'offer':
        case 'answer':
        case 'candidate':
          final from = decoded['from'];
          final payload = decoded['payload'];
          if (from is! String || payload is! Map<String, dynamic>) {
            _setError('The host sent an invalid WebRTC message.');
            return;
          }
          void sendSignal(String type, Map<String, dynamic> data) {
            _sendClientSignal(type, from, data);
          }
          switch (decoded['type']) {
            case 'offer':
              await _webRtcService.handleOffer(from, payload, sendSignal);
              break;
            case 'answer':
              await _webRtcService.handleAnswer(from, payload, sendSignal);
              break;
            case 'candidate':
              await _webRtcService.handleCandidate(from, payload, sendSignal);
              break;
          }
          break;
        case 'error':
          final error = decoded['message'];
          if (!_isReconnecting) {
            _setError(error is String ? error : 'The host rejected a request.');
          }
          _completeReconnectAttempt(false);
          break;
        default:
          _setError('The host sent an unknown message.');
          break;
      }
    } on FormatException catch (error) {
      _setError('The host sent invalid JSON: $error');
    } on TypeError catch (error) {
      _setError('The host sent an invalid peer list: $error');
    } catch (error) {
      _setError('WebRTC negotiation failed: $error');
    }
  }

  Future<void> _sendClientOffer(String peerId) async {
    final clientPeerId = _clientPeerId;
    if (clientPeerId == null) {
      _setError('Cannot negotiate audio before joining the room.');
      return;
    }
    try {
      await _webRtcService.createOffer(
        peerId,
        (type, payload) => _sendClientSignal(type, peerId, payload),
      );
    } catch (error) {
      _setError('Could not start audio with $peerId: $error');
    }
  }

  void _sendClientSignal(
    String type,
    String targetId,
    Map<String, dynamic> payload,
  ) {
    final channel = _clientChannel;
    final peerId = _clientPeerId;
    if (channel == null || peerId == null) return;
    channel.sink.add(
      jsonEncode({
        'type': type,
        'from': peerId,
        'to': targetId,
        'payload': payload,
      }),
    );
  }

  Future<void> _handleClientDisconnect(
    String message, {
    required WebSocketChannel channel,
  }) async {
    if (_isLeavingRoom ||
        _roomClosed ||
        _roomKicked ||
        _joinRejected ||
        !identical(channel, _clientChannel)) {
      return;
    }

    _clientChannel = null;
    final subscription = _clientSubscription;
    _clientSubscription = null;
    try {
      await subscription?.cancel();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Open Voice signaling',
          context: ErrorDescription('while handling a disconnected socket'),
        ),
      );
    }

    if (_isReconnecting) {
      _completeReconnectAttempt(false);
      return;
    }

    _qualityReportTimer?.cancel();
    _qualityReportTimer = null;
    try {
      await _webRtcService.dispose();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Open Voice signaling',
          context: ErrorDescription('while releasing disconnected audio'),
        ),
      );
    }

    if (_isLeavingRoom || _roomClosed || _roomKicked) return;
    if (!_joinApproved || _clientReconnectToken == null) {
      _clientPeerId = null;
      _clientDisplayName = null;
      _clientReconnectToken = null;
      _clearChatMessages();
      _isWaitingForApproval = false;
      _setError(message);
      return;
    }

    _isReconnecting = true;
    _reconnectionFailed = false;
    _errorMessage = null;
    _reconnectDeadlineTimer?.cancel();
    _reconnectDeadlineTimer = Timer(_reconnectionWindow, _markReconnectFailed);
    notifyListeners();
    unawaited(_attemptReconnectUntilDeadline());
  }

  void _startQualityReporting() {
    if (_isHost || _qualityReportTimer != null) return;
    _qualityReportTimer = Timer.periodic(
      _qualityReportingInterval,
      (_) => unawaited(_reportConnectionQuality()),
    );
    unawaited(_reportConnectionQuality());
  }

  Future<void> _reportConnectionQuality() async {
    if (!_joinApproved || _isReconnecting) return;
    final channel = _clientChannel;
    if (channel == null) return;
    try {
      final quality = await _webRtcService.getConnectionQuality(_hostPeerId);
      if (!identical(channel, _clientChannel) || _isReconnecting) return;
      channel.sink.add(
        jsonEncode({'type': 'quality_report', 'quality': quality.name}),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Open Voice connection quality',
          context: ErrorDescription('while reporting connection quality'),
        ),
      );
    }
  }

  Future<void> _handleKickedFromRoom() async {
    if (_roomKicked) return;
    _roomKicked = true;
    _isReconnecting = false;
    _reconnectDeadlineTimer?.cancel();
    _reconnectDeadlineTimer = null;
    _qualityReportTimer?.cancel();
    _qualityReportTimer = null;
    _completeReconnectAttempt(false);
    _reconnectAttempt = null;
    final channel = _clientChannel;
    _clientChannel = null;
    Object? cleanupError;
    StackTrace? cleanupStackTrace;
    try {
      await _webRtcService.dispose();
    } catch (error, stackTrace) {
      cleanupError = error;
      cleanupStackTrace = stackTrace;
    }
    try {
      await _soundEffects.play('leave');
      await channel?.sink
          .close(WebSocketStatus.normalClosure)
          .timeout(const Duration(seconds: 2));
    } catch (error, stackTrace) {
      cleanupError ??= error;
      cleanupStackTrace ??= stackTrace;
    }

    _hostIp = null;
    _port = null;
    _clientPeerId = null;
    _clientDisplayName = null;
    _clientReconnectToken = null;
    _pendingTurnServer = null;
    _isWaitingForApproval = false;
    _speakingPeerIds = const {};
    _clearChatMessages();
    _setPeers(const []);
    _errorMessage = 'You have been kicked from the room by the host.';
    if (!_disposed) notifyListeners();

    if (cleanupError != null) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: cleanupError,
          stack: cleanupStackTrace,
          library: 'Open Voice signaling',
          context: ErrorDescription('while cleaning up after being kicked'),
        ),
      );
    }
  }

  Future<void> _handleRoomClosed() async {
    if (_roomClosed) return;
    _roomClosed = true;
    _isReconnecting = false;
    _reconnectDeadlineTimer?.cancel();
    _reconnectDeadlineTimer = null;
    _qualityReportTimer?.cancel();
    _qualityReportTimer = null;
    _completeReconnectAttempt(false);
    _reconnectAttempt = null;
    _errorMessage = 'The host has closed the room.';
    if (!_disposed) notifyListeners();
    final channel = _clientChannel;
    _clientChannel = null;
    Object? cleanupError;
    StackTrace? cleanupStackTrace;

    try {
      await _webRtcService.dispose();
    } catch (error, stackTrace) {
      cleanupError = error;
      cleanupStackTrace = stackTrace;
    }

    try {
      await channel?.sink
          .close(WebSocketStatus.normalClosure)
          .timeout(const Duration(seconds: 2));
    } catch (error, stackTrace) {
      cleanupError ??= error;
      cleanupStackTrace ??= stackTrace;
    }

    final subscription = _clientSubscription;
    _clientSubscription = null;
    try {
      await subscription?.cancel();
    } catch (error, stackTrace) {
      cleanupError ??= error;
      cleanupStackTrace ??= stackTrace;
    }

    _hostIp = null;
    _port = null;
    _clientPeerId = null;
    _clientDisplayName = null;
    _clientReconnectToken = null;
    _speakingPeerIds = const {};
    _clearChatMessages();
    _setPeers(const []);

    if (cleanupError != null) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: cleanupError,
          stack: cleanupStackTrace,
          library: 'Open Voice signaling',
          context: ErrorDescription(
            'while cleaning up after the host closed the room',
          ),
        ),
      );
    }
  }

  void _reportRoomShutdownError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Open Voice signaling',
        context: ErrorDescription('while shutting down the hosted room'),
      ),
    );
  }

  Future<void> setMuted(bool muted) async {
    await _webRtcService.setMuted(muted);
    notifyListeners();
  }

  Future<List<AudioDevice>> getAudioInputs() => _webRtcService.getAudioInputs();

  Future<List<AudioDevice>> getAudioOutputs() =>
      _webRtcService.getAudioOutputs();

  Future<void> selectAudioInput(String? deviceId) async {
    await _webRtcService.selectAudioInput(deviceId);
    await _appSettings.setAudioInputDeviceId(
      _webRtcService.selectedInputDeviceId,
    );
    notifyListeners();
  }

  Future<void> selectAudioOutput(String? deviceId) async {
    await _webRtcService.selectAudioOutput(deviceId);
    await _appSettings.setAudioOutputDeviceId(
      _webRtcService.selectedOutputDeviceId,
    );
    notifyListeners();
  }

  double peerVolume(String peerId) => _webRtcService.peerVolume(peerId);

  Future<void> setPeerVolume(String peerId, double volume) async {
    await _webRtcService.setPeerVolume(peerId, volume);
    notifyListeners();
  }

  Future<double> togglePeerMute(String peerId) async {
    final volume = await _webRtcService.togglePeerMute(peerId);
    notifyListeners();
    return volume;
  }

  void _broadcastSound(String sound) {
    unawaited(_soundEffects.play(sound));
    final message = jsonEncode({'type': 'play_sound', 'sound': sound});
    for (final channel in _connectedPeers.keys.toList()) {
      try {
        channel.sink.add(message);
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'Open Voice signaling',
            context: ErrorDescription('while broadcasting the $sound sound'),
          ),
        );
      }
    }
  }

  Future<AppLocalizations> _loadNotificationLocalizations() async {
    final preferredLocale =
        _appSettings.locale ??
        WidgetsBinding.instance.platformDispatcher.locale;
    final locale = basicLocaleListResolution([
      preferredLocale,
    ], AppLocalizations.supportedLocales);
    return AppLocalizations.delegate.load(locale);
  }

  Future<void> _showJoinRequestNotification(String name) async {
    final l10n = await _loadNotificationLocalizations();
    await _showSystemNotification(
      title: l10n.systemNotificationJoinRequestTitle,
      body: l10n.systemNotificationJoinRequestBody(name),
    );
  }

  Future<void> _showJoinAcceptedNotification(String room) async {
    final l10n = await _loadNotificationLocalizations();
    await _showSystemNotification(
      title: l10n.systemNotificationJoinAcceptedTitle,
      body: l10n.systemNotificationJoinAcceptedBody(room),
    );
  }

  Future<void> _showJoinRejectedNotification() async {
    final l10n = await _loadNotificationLocalizations();
    await _showSystemNotification(
      title: l10n.systemNotificationJoinRejectedTitle,
      body: l10n.systemNotificationJoinRejectedBody,
    );
  }

  Future<void> _showSystemNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _notifications.show(title: title, body: body);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Open Voice notifications',
          context: ErrorDescription('while displaying "$title"'),
        ),
      );
    }
  }

  void sendChatMessage(String text) {
    final messageText = text.trim();
    if (messageText.isEmpty) return;
    if (messageText.length > 2000) {
      throw const SignalingException('Chat message is too long.');
    }

    final now = DateTime.now();
    if (_isHost) {
      final message = ChatMessage(
        id: 'host:${++_chatSequence}',
        senderName: _hostDisplayName,
        text: messageText,
        timestamp: now,
      );
      _addChatMessage(message);
      final encoded = jsonEncode(message.toJson());
      for (final channel in _connectedPeers.keys.toList()) {
        try {
          channel.sink.add(encoded);
        } catch (error, stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'Open Voice chat',
              context: ErrorDescription(
                'while broadcasting a chat message to room members',
              ),
            ),
          );
        }
      }
      return;
    }

    final channel = _clientChannel;
    final senderName = _clientDisplayName;
    if (channel == null || !_joinApproved || senderName == null) {
      throw const SignalingException(
        'Join the room before sending chat messages.',
      );
    }
    final message = ChatMessage(
      id: '${_clientPeerId ?? 'guest'}:${now.microsecondsSinceEpoch}',
      senderName: senderName,
      text: messageText,
      timestamp: now,
    );
    _addChatMessage(message);
    try {
      channel.sink.add(jsonEncode(message.toJson()));
    } catch (error) {
      _chatMessages.removeWhere((item) => item.id == message.id);
      notifyListeners();
      rethrow;
    }
  }

  void _addChatMessage(ChatMessage message) {
    final existingIndex = _chatMessages.indexWhere(
      (item) => item.id == message.id,
    );
    if (existingIndex == -1) {
      _chatMessages.add(message);
    } else {
      _chatMessages[existingIndex] = message;
    }
    if (!_disposed) notifyListeners();
  }

  void _clearChatMessages() {
    if (_chatMessages.isEmpty) return;
    _chatMessages.clear();
    if (!_disposed) notifyListeners();
  }

  void _broadcastPeerList() {
    final peers = <RoomPeer>[
      RoomPeer(
        id: _hostPeerId,
        name: _hostDisplayName,
        role: PeerRole.moderator,
        quality: ConnectionQuality.strong,
      ),
      ..._connectedPeers.values,
      ..._disconnectedPeers.values,
    ];
    _setPeers(peers);
    final message = jsonEncode({
      'type': 'peer_list',
      'peers': peers
          .map(
            (peer) => {
              'id': peer.id,
              'name': peer.name,
              'role': peer.role.name,
              'quality': peer.quality.name,
              'isConnected': peer.isConnected,
            },
          )
          .toList(),
    });
    for (final channel in _connectedPeers.keys.toList()) {
      channel.sink.add(message);
    }
  }

  Map<String, dynamic> _peerToJson(RoomPeer peer) => {
    'id': peer.id,
    'name': peer.name,
    'role': peer.role.name,
    'quality': peer.quality.name,
    'isConnected': peer.isConnected,
  };

  void _sendProtocolError(WebSocketChannel channel, String message) {
    channel.sink.add(jsonEncode({'type': 'error', 'message': message}));
  }

  void _setPeers(List<RoomPeer> peers) {
    _peers = List.unmodifiable(peers);
    if (!_disposed) notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    if (!_disposed) notifyListeners();
  }

  void _handleSpeakingChanged(Set<String> peerIds) {
    final updatedPeerIds = {...peerIds};
    final localId = localPeerId;
    if (_webRtcService.isLocalSpeaking && localId != null) {
      updatedPeerIds.add(localId);
    } else if (localId != null) {
      updatedPeerIds.remove(localId);
    }
    _speakingPeerIds = Set.unmodifiable(updatedPeerIds);
    if (!_disposed) notifyListeners();
  }

  void _handleLocalSpeakingChanged(bool isSpeaking) {
    final localId = localPeerId;
    if (localId == null) return;
    final updatedPeerIds = {..._speakingPeerIds};
    if (isSpeaking) {
      updatedPeerIds.add(localId);
    } else {
      updatedPeerIds.remove(localId);
    }
    _speakingPeerIds = Set.unmodifiable(updatedPeerIds);
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_disposeRoomResources());
    super.dispose();
  }

  Future<void> _disposeRoomResources() async {
    Object? cleanupError;
    StackTrace? cleanupStackTrace;
    void recordCleanupError(Object error, StackTrace stackTrace) {
      cleanupError ??= error;
      cleanupStackTrace ??= stackTrace;
    }

    _reconnectDeadlineTimer?.cancel();
    _qualityReportTimer?.cancel();
    for (final timer in _disconnectedPeerTimers.values) {
      timer.cancel();
    }
    _disconnectedPeerTimers.clear();
    _disconnectedPeers.clear();
    _reconnectTokensByPeerId.clear();
    _pendingPeerNotifications.clear();
    _completeReconnectAttempt(false);

    try {
      await _webRtcService.dispose();
    } catch (error, stackTrace) {
      recordCleanupError(error, stackTrace);
    }
    final subscription = _clientSubscription;
    _clientSubscription = null;
    try {
      await subscription?.cancel();
    } catch (error, stackTrace) {
      recordCleanupError(error, stackTrace);
    }
    final clientChannel = _clientChannel;
    _clientChannel = null;
    try {
      await clientChannel?.sink.close(WebSocketStatus.goingAway);
    } catch (error, stackTrace) {
      recordCleanupError(error, stackTrace);
    }
    final channels = _connectedPeers.keys.toList();
    _connectedPeers.clear();
    for (final channel in channels) {
      try {
        await channel.sink.close(WebSocketStatus.goingAway);
      } catch (error, stackTrace) {
        recordCleanupError(error, stackTrace);
      }
    }
    final server = _server;
    _server = null;
    try {
      await server?.close(force: true);
    } catch (error, stackTrace) {
      recordCleanupError(error, stackTrace);
    }
    if (cleanupError != null) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: cleanupError!,
          stack: cleanupStackTrace,
          library: 'Open Voice signaling',
          context: ErrorDescription('while disposing room resources'),
        ),
      );
    }
  }
}
