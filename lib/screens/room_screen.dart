import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_error.dart';
import '../route_observer.dart';
import '../services/signaling_service.dart';
import '../services/sound_effects_service.dart';
import '../services/webrtc_service.dart';
import 'chat_screen.dart';
import 'home_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    required this.isHost,
    required this.port,
    this.hostIp,
    super.key,
  });

  final bool isHost;
  final String? hostIp;
  final int port;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with RouteAware {
  bool _isLeaving = false;
  bool _isConfirmingLeave = false;
  bool _isChatOpen = false;
  bool _isRouteVisible = true;
  final Map<String, double> _peerVolumes = {};
  SignalingService? _signalingService;
  PageRoute<dynamic>? _observedRoute;
  final Set<String> _seenChatMessageIds = {};
  final Queue<ChatMessage> _chatNotificationQueue = Queue<ChatMessage>();
  OverlayEntry? _chatNotificationEntry;
  Timer? _chatNotificationTimer;
  bool _isChatNotificationVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _observedRoute) {
      if (_observedRoute != null) appRouteObserver.unsubscribe(this);
      _observedRoute = route;
      appRouteObserver.subscribe(this, route);
    }

    final service = context.read<SignalingService>();
    if (_signalingService == service) return;
    _signalingService?.removeListener(_handleSignalingUpdate);
    _signalingService = service;
    _seenChatMessageIds
      ..clear()
      ..addAll(service.chatMessages.map((message) => message.id));
    service.addListener(_handleSignalingUpdate);
  }

  void _handleSignalingUpdate() {
    if (!mounted) return;
    final service = _signalingService;
    if (service != null) {
      for (final message in service.chatMessages) {
        if (!_seenChatMessageIds.add(message.id)) continue;
        if (message.isHistorical) continue;
        final shouldNotify = _isRouteVisible && !(_isWideLayout && _isChatOpen);
        if (message.senderName != service.localDisplayName && shouldNotify) {
          _enqueueChatNotification(message);
        }
      }
    }
    if (service?.reconnectionFailed == true && !_isLeaving) {
      _isLeaving = true;
      unawaited(_returnHomeAfterReconnectFailure(service!));
      return;
    }
    if (service == null ||
        (!service.roomClosed && !service.roomKicked) ||
        _isLeaving) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    _isLeaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            service.roomKicked ? l10n!.kickedFromRoom : l10n!.roomClosed,
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      unawaited(
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
          (_) => false,
        ),
      );
    });
  }

  Future<void> _returnHomeAfterReconnectFailure(
    SignalingService service,
  ) async {
    try {
      await service.leaveRoom();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Open Voice room',
          context: ErrorDescription(
            'while leaving after reconnect attempts failed',
          ),
        ),
      );
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.reconnectFailed)));
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Color _qualityColor(BuildContext context, ConnectionQuality quality) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (quality) {
      ConnectionQuality.strong =>
        isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
      ConnectionQuality.medium =>
        isDark ? const Color(0xFFFFD54F) : const Color(0xFFB26A00),
      ConnectionQuality.weak =>
        isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828),
    };
  }

  String _qualityLabel(AppLocalizations l10n, ConnectionQuality quality) =>
      switch (quality) {
        ConnectionQuality.strong => l10n.qualityStrong,
        ConnectionQuality.medium => l10n.qualityMedium,
        ConnectionQuality.weak => l10n.qualityWeak,
      };

  Future<void> _showPeerVolumeMenu(RoomPeer peer) async {
    final service = _signalingService;
    if (service == null || !peer.isConnected) return;
    var volume = _peerVolumes[peer.id] ?? service.peerVolume(peer.id);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${AppLocalizations.of(context)!.peerVolume}: ${peer.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('0%'),
                    Expanded(
                      child: Slider(
                        value: volume.clamp(0.0, 2.0).toDouble(),
                        min: 0,
                        max: 2,
                        divisions: 20,
                        label: '${(volume * 100).round()}%',
                        onChanged: (value) {
                          setSheetState(() => volume = value);
                          if (mounted) {
                            setState(() => _peerVolumes[peer.id] = value);
                          }
                        },
                        onChangeEnd: (value) =>
                            unawaited(_applyPeerVolume(peer.id, value)),
                      ),
                    ),
                    const Text('200%'),
                  ],
                ),
                Center(child: Text('${(volume * 100).round()}%')),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      final updatedVolume = await service.togglePeerMute(
                        peer.id,
                      );
                      if (!mounted) return;
                      setSheetState(() => volume = updatedVolume);
                      setState(() => _peerVolumes[peer.id] = updatedVolume);
                    } catch (error, stackTrace) {
                      _reportPeerVolumeError(error, stackTrace);
                    }
                  },
                  icon: Icon(
                    volume == 0
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                  label: Text(
                    volume == 0
                        ? AppLocalizations.of(context)!.unmute
                        : AppLocalizations.of(context)!.mute,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyPeerVolume(String peerId, double volume) async {
    final service = _signalingService;
    if (service == null) return;
    try {
      await service.setPeerVolume(peerId, volume);
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() {
          _peerVolumes[peerId] = service.peerVolume(peerId);
        });
      }
      _reportPeerVolumeError(error, stackTrace);
    }
  }

  void _reportPeerVolumeError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Open Voice room',
        context: ErrorDescription('while changing a peer volume'),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizedError(AppLocalizations.of(context)!, error)),
        ),
      );
    }
  }

  bool get _isWideLayout => mounted && MediaQuery.sizeOf(context).width >= 800;
  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;

  @override
  void didPush() {
    _isRouteVisible = true;
  }

  @override
  void didPushNext() {
    _isRouteVisible = false;
    _dismissChatNotification();
  }

  @override
  void didPopNext() {
    _isRouteVisible = true;
  }

  @override
  void didPop() {
    _isRouteVisible = false;
    _dismissChatNotification();
  }

  void _enqueueChatNotification(ChatMessage message) {
    _chatNotificationQueue.addLast(message);
    if (_chatNotificationEntry == null) _showNextChatNotification();
  }

  void _showNextChatNotification() {
    if (!mounted || _chatNotificationQueue.isEmpty) return;
    final message = _chatNotificationQueue.removeFirst();
    final isDesktop = _isWideLayout;
    _isChatNotificationVisible = true;
    _chatNotificationEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            left: isDesktop ? null : 16,
            right: isDesktop && _isRtl && _isChatOpen ? 336 : 16,
            bottom: isDesktop ? 100 : 104,
            width: isDesktop ? 420 : null,
            child: isDesktop
                ? Align(
                    alignment: Alignment.bottomRight,
                    child: _buildChatNotificationCard(context, message),
                  )
                : Center(child: _buildChatNotificationCard(context, message)),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_chatNotificationEntry!);
    _chatNotificationTimer = Timer(
      const Duration(seconds: 5),
      _startChatNotificationExit,
    );
  }

  Widget _buildChatNotificationCard(BuildContext context, ChatMessage message) {
    final isDesktop = _isWideLayout;
    final localName = _signalingService?.localDisplayName ?? '';
    final isMentioned =
        localName.isNotEmpty && message.text.contains('@$localName');
    final mentionColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFD54F)
        : const Color(0xFFB8860B);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isDesktop ? 420 : 560),
      child: AnimatedSlide(
        offset: _isChatNotificationVisible
            ? Offset.zero
            : const Offset(0, 0.16),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _isChatNotificationVisible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _openChatFromNotification,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.chat_bubble_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.senderName,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (isMentioned) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.alternate_email_rounded,
                                  size: 16,
                                  color: mentionColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppLocalizations.of(context)!
                                      .youWereMentioned,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: mentionColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            message.text,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openChatFromNotification() {
    final wasChatOpen = _isWideLayout && _isChatOpen;
    _dismissChatNotification();
    if (!wasChatOpen) _openChat(wideLayout: _isWideLayout);
  }

  void _startChatNotificationExit() {
    _chatNotificationTimer = null;
    _isChatNotificationVisible = false;
    _chatNotificationEntry?.markNeedsBuild();
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      _chatNotificationEntry?.remove();
      _chatNotificationEntry = null;
      _showNextChatNotification();
    });
  }

  void _dismissChatNotification() {
    _chatNotificationTimer?.cancel();
    _chatNotificationTimer = null;
    _isChatNotificationVisible = false;
    _chatNotificationEntry?.remove();
    _chatNotificationEntry = null;
    _chatNotificationQueue.clear();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _signalingService?.removeListener(_handleSignalingUpdate);
    _dismissChatNotification();
    super.dispose();
  }

  Future<void> _openAudioDeviceSheet() async {
    final signaling = context.read<SignalingService>();
    final l10n = AppLocalizations.of(context)!;
    late List<AudioDevice> inputs;
    late List<AudioDevice> outputs;
    try {
      inputs = await signaling.getAudioInputs();
      outputs = await signaling.getAudioOutputs();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.requestFailed('$error'))));
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        var selectedInput =
            signaling.selectedInputDeviceId ??
            inputs.where((device) => device.isDefault).firstOrNull?.id ??
            '';
        var selectedOutput =
            signaling.selectedOutputDeviceId ??
            outputs.where((device) => device.isDefault).firstOrNull?.id ??
            '';
        var isChangingInput = false;
        var isChangingOutput = false;
        var isRefreshing = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> refreshDevices() async {
              setSheetState(() {
                isRefreshing = true;
                inputs = [];
                outputs = [];
              });
              try {
                final refreshed = await Future.wait([
                  signaling.getAudioInputs(),
                  signaling.getAudioOutputs(),
                ]);
                if (!context.mounted) return;
                setSheetState(() {
                  inputs = refreshed[0];
                  outputs = refreshed[1];
                  isRefreshing = false;
                });
              } catch (error) {
                if (!context.mounted) return;
                setSheetState(() => isRefreshing = false);
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.requestFailed('$error'))),
                );
              }
            }

            Future<void> changeInput(String? deviceId) async {
              setSheetState(() {
                selectedInput = deviceId ?? '';
                isChangingInput = true;
              });
              try {
                await signaling.selectAudioInput(deviceId);
                if (!context.mounted) return;
                setSheetState(() {
                  selectedInput = signaling.selectedInputDeviceId ?? '';
                });
              } catch (error) {
                if (!context.mounted) return;
                setSheetState(() {
                  selectedInput = signaling.selectedInputDeviceId ?? '';
                });
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.requestFailed('$error'))),
                );
              } finally {
                if (context.mounted) {
                  setSheetState(() => isChangingInput = false);
                }
              }
            }

            Future<void> changeOutput(String? deviceId) async {
              setSheetState(() {
                selectedOutput = deviceId ?? '';
                isChangingOutput = true;
              });
              try {
                await signaling.selectAudioOutput(deviceId);
                if (!context.mounted) return;
                setSheetState(() {
                  selectedOutput = signaling.selectedOutputDeviceId ?? '';
                });
              } catch (error) {
                if (!context.mounted) return;
                setSheetState(() {
                  selectedOutput = signaling.selectedOutputDeviceId ?? '';
                });
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.requestFailed('$error'))),
                );
              } finally {
                if (context.mounted) {
                  setSheetState(() => isChangingOutput = false);
                }
              }
            }

            Widget deviceOption({
              required String title,
              required String value,
              required String groupValue,
              required bool enabled,
              required ValueChanged<String?>? onChanged,
            }) {
              final isSelected = value == groupValue;
              return ListTile(
                dense: true,
                selected: isSelected,
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                title: Text(title),
                onTap: enabled ? () => onChanged?.call(value) : null,
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.audioDevices,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.refresh,
                          onPressed: isRefreshing ? null : refreshDevices,
                          icon: isRefreshing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.inputMicrophone,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (inputs.isEmpty)
                      ListTile(title: Text(l10n.noAudioDevices)),
                    for (final device in inputs)
                      deviceOption(
                        title: device.isDefault
                            ? '${device.label} - ${l10n.defaultDeviceSuffix}'
                            : device.label,
                        value: device.id,
                        groupValue: selectedInput,
                        enabled: !isChangingInput,
                        onChanged: (_) => changeInput(device.id),
                      ),
                    const Divider(),
                    Text(
                      l10n.outputSpeaker,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (outputs.isEmpty)
                      ListTile(title: Text(l10n.noAudioDevices)),
                    for (final device in outputs)
                      deviceOption(
                        title: device.isDefault
                            ? '${device.label} - ${l10n.defaultDeviceSuffix}'
                            : device.label,
                        value: device.id,
                        groupValue: selectedOutput,
                        enabled: !isChangingOutput,
                        onChanged: (_) => changeOutput(device.id),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleMute() async {
    final signaling = context.read<SignalingService>();
    final soundEffects = context.read<SoundEffectsService>();
    final willMute = !signaling.isMuted;
    final l10n = AppLocalizations.of(context)!;
    try {
      await signaling.setMuted(willMute);
      unawaited(soundEffects.play(willMute ? 'mute' : 'unmute'));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.couldNotChangeMic('$error'))));
    }
  }

  Future<void> _leaveRoom() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isLeaving) return;
    _isLeaving = true;
    try {
      await context.read<SignalingService>().leaveRoom();
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      await Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (error) {
      _isLeaving = false;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.couldNotLeaveRoom('$error'))));
    }
  }

  Future<void> _approveJoinRequest(String requestId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<SignalingService>().approveJoinRequest(requestId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.couldNotApprove('$error'))));
    }
  }

  Future<void> _rejectJoinRequest(String requestId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<SignalingService>().rejectJoinRequest(requestId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.couldNotReject('$error'))));
    }
  }

  Future<void> _kickPeer(RoomPeer peer) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldKick = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.kickTitle(peer.name)),
        content: Text(l10n.kickConfirm(peer.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l10n.kick),
          ),
        ],
      ),
    );
    if (!mounted || shouldKick != true) return;

    try {
      await context.read<SignalingService>().kickPeer(peer.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotKick(peer.name, '$error'))),
      );
    }
  }

  Future<void> _confirmLeaveRoom() async {
    if (_isLeaving || _isConfirmingLeave) return;
    _isConfirmingLeave = true;
    final l10n = AppLocalizations.of(context)!;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.confirmLeaveRoomTitle),
          content: Text(l10n.confirmLeaveRoomMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.leaveRoom),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      await _leaveRoom();
    } finally {
      _isConfirmingLeave = false;
    }
  }

  void _openChat({required bool wideLayout}) {
    if (wideLayout) {
      _setChatPanelOpen(!_isChatOpen);
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ChatScreen()));
  }

  void _setChatPanelOpen(bool isOpen) {
    setState(() => _isChatOpen = isOpen);
    _chatNotificationEntry?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    final signaling = context.watch<SignalingService>();
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isMuted = signaling.isMuted;
    final isWideLayout = MediaQuery.sizeOf(context).width >= 800;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final roomTitle = signaling.isHost
        ? l10n.hostingOn(
            signaling.localIp ?? '...',
            '${signaling.port ?? widget.port}',
          )
        : l10n.roomAt(
            signaling.hostIp ?? widget.hostIp ?? '...',
            '${signaling.port ?? widget.port}',
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeaveRoom());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(roomTitle)),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              textDirection: TextDirection.ltr,
              children: [
                if (isWideLayout && _isChatOpen && !isRtl)
                  SizedBox(
                    width: 320,
                    child: ChatPanel(
                      isSidePanel: true,
                      onClose: () => _setChatPanelOpen(false),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (signaling.isReconnecting)
                        MaterialBanner(
                          content: Text(l10n.connectionLostReconnecting),
                          leading: const Icon(Icons.wifi_off_rounded),
                          actions: const [SizedBox.shrink()],
                        ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 550),
                            child: SizedBox(
                              width: double.infinity,
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                colorScheme.primaryContainer,
                                            foregroundColor:
                                                colorScheme.onPrimaryContainer,
                                            child: const Icon(
                                              Icons.graphic_eq_rounded,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  signaling.isHost
                                                      ? l10n.youAreHosting
                                                      : signaling
                                                                .errorMessage ==
                                                            null
                                                      ? l10n.connected
                                                      : l10n.connectionIssue,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  signaling.errorMessage == null
                                                      ? (signaling.isHost
                                                            ? l10n.shareRoom(
                                                                signaling
                                                                        .localIp ??
                                                                    '...',
                                                                '${signaling.port ?? widget.port}',
                                                              )
                                                            : l10n.youJoined(
                                                                signaling
                                                                        .hostIp ??
                                                                    widget
                                                                        .hostIp ??
                                                                    '...',
                                                                '${signaling.port ?? widget.port}',
                                                              ))
                                                      : localizedError(
                                                          l10n,
                                                          signaling
                                                              .errorMessage!,
                                                        ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            signaling
                                                                    .errorMessage ==
                                                                null
                                                            ? colorScheme
                                                                  .onSurfaceVariant
                                                            : colorScheme.error,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    l10n.peopleInRoom,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  if (signaling.peers.isEmpty)
                                    Card(
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.people_outline_rounded,
                                        ),
                                        title: Text(l10n.waitingMembers),
                                      ),
                                    ),
                                  for (final peer in signaling.peers)
                                    Builder(
                                      builder: (context) {
                                        final isSpeaking = signaling
                                            .speakingPeerIds
                                            .contains(peer.id);
                                        final isRemotePeer =
                                            peer.id != signaling.localPeerId;
                                        final isLocallyMuted =
                                            isRemotePeer &&
                                            (_peerVolumes[peer.id] ??
                                                    signaling.peerVolume(
                                                      peer.id,
                                                    )) ==
                                                0;
                                        final desktopScale = isWideLayout
                                            ? 1.2
                                            : 1.0;
                                        return Card(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 5,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            side: BorderSide(
                                              color: isSpeaking
                                                  ? Colors.green
                                                  : colorScheme.outlineVariant,
                                              width: isSpeaking ? 2 : 0.5,
                                            ),
                                          ),
                                          child: ListTile(
                                            onTap:
                                                isRemotePeer && peer.isConnected
                                                ? () => unawaited(
                                                    _showPeerVolumeMenu(peer),
                                                  )
                                                : null,
                                            dense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 16 * desktopScale,
                                                  vertical: 2,
                                                ),
                                            minVerticalPadding: 4,
                                            leading: CircleAvatar(
                                              radius: 20,
                                              backgroundColor: colorScheme
                                                  .secondaryContainer,
                                              foregroundColor: colorScheme
                                                  .onSecondaryContainer,
                                              child: Text(
                                                peer.name.characters.first
                                                    .toUpperCase(),
                                              ),
                                            ),
                                            title: Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    peer.name,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize:
                                                          16 * desktopScale,
                                                    ),
                                                  ),
                                                ),
                                                if (isLocallyMuted) ...[
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    Icons.volume_off_rounded,
                                                    size: 18 * desktopScale,
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            subtitle: Text(
                                              !peer.isConnected
                                                  ? l10n.disconnected
                                                  : peer.role ==
                                                        PeerRole.moderator
                                                  ? l10n.moderator
                                                  : l10n.inRoom,
                                              style: TextStyle(
                                                fontSize: 14 * desktopScale,
                                                color: peer.isConnected
                                                    ? null
                                                    : colorScheme
                                                          .onSurfaceVariant,
                                              ),
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .signal_cellular_alt_rounded,
                                                      color: _qualityColor(
                                                        context,
                                                        peer.quality,
                                                      ),
                                                      size: 20,
                                                    ),
                                                    Text(
                                                      _qualityLabel(
                                                        l10n,
                                                        peer.quality,
                                                      ),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color:
                                                                _qualityColor(
                                                                  context,
                                                                  peer.quality,
                                                                ),
                                                            fontSize:
                                                                10 *
                                                                desktopScale,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  peer.role ==
                                                          PeerRole.moderator
                                                      ? Icons.shield_rounded
                                                      : Icons.mic_rounded,
                                                  color: colorScheme.primary,
                                                ),
                                                if (signaling.isHost &&
                                                    peer.role !=
                                                        PeerRole.moderator)
                                                  IconButton(
                                                    tooltip: l10n
                                                        .kickPeerTooltip(
                                                          peer.name,
                                                        ),
                                                    onPressed: () =>
                                                        _kickPeer(peer),
                                                    icon: const Icon(
                                                      Icons.block_rounded,
                                                    ),
                                                    color: colorScheme.error,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (signaling.isHost &&
                          signaling.pendingJoinRequests.isNotEmpty)
                        LayoutBuilder(
                          builder: (context, _) {
                            final isWideScreen =
                                MediaQuery.sizeOf(context).width >= 700;
                            return Align(
                              alignment: isWideScreen
                                  ? Alignment.centerRight
                                  : Alignment.center,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 400,
                                  maxHeight: 180,
                                ),
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  children: [
                                    for (final request
                                        in signaling.pendingJoinRequests)
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l10n.wantsToJoin(request.name),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        _rejectJoinRequest(
                                                          request.id,
                                                        ),
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          colorScheme.error,
                                                    ),
                                                    child: Text(l10n.reject),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        _approveJoinRequest(
                                                          request.id,
                                                        ),
                                                    style:
                                                        FilledButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.green,
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                    child: Text(l10n.approve),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isDarkTheme =
                                    Theme.of(context).brightness ==
                                    Brightness.dark;
                                final muteBackground = isMuted
                                    ? colorScheme.error
                                    : colorScheme.primary;
                                final muteForeground = isMuted
                                    ? colorScheme.onError
                                    : colorScheme.onPrimary;
                                final muteButton = Expanded(
                                  flex: 5,
                                  child: SizedBox(
                                    height: 64,
                                    child: Material(
                                      color: muteBackground,
                                      shape: const StadiumBorder(),
                                      clipBehavior: Clip.antiAlias,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              onTap: _toggleMute,
                                              child: SizedBox.expand(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        isMuted
                                                            ? Icons
                                                                  .mic_off_rounded
                                                            : Icons.mic_rounded,
                                                        color: muteForeground,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Flexible(
                                                        child: Text(
                                                          isMuted
                                                              ? l10n.unmute
                                                              : l10n.mute,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            color:
                                                                muteForeground,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 28,
                                            color: muteForeground.withValues(
                                              alpha: 0.45,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 48,
                                            child: Tooltip(
                                              message: l10n.audioDevices,
                                              child: InkWell(
                                                onTap: _openAudioDeviceSheet,
                                                child: SizedBox.expand(
                                                  child: Icon(
                                                    Icons.expand_more_rounded,
                                                    color: muteForeground,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                                final chatButton = Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 64,
                                    child: FilledButton(
                                      onPressed: () =>
                                          _openChat(wideLayout: isWideLayout),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: isDarkTheme
                                            ? const Color(0xFF4B6A9A)
                                            : const Color(0xFF2E5AAC),

                                        foregroundColor: isDarkTheme
                                            ? const Color(0xFFE3F2FD)
                                            : Colors.white,

                                        shape: const StadiumBorder(),
                                        minimumSize: const Size.fromHeight(64),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                      ),
                                      child: Tooltip(
                                        message: l10n.roomChat,
                                        child: Icon(
                                          _isChatOpen && isWideLayout
                                              ? Icons.chat_rounded
                                              : Icons
                                                    .chat_bubble_outline_rounded,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                                final leaveButton = Expanded(
                                  flex: 5,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLeaving ? null : _leaveRoom,
                                    icon: const Icon(Icons.call_end_rounded),
                                    label: Text(
                                      l10n.leaveRoom,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(64),
                                      foregroundColor: colorScheme.error,
                                      shape: const StadiumBorder(),
                                      side: BorderSide(
                                        color: colorScheme.error,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 20,
                                      ),
                                    ),
                                  ),
                                );
                                return Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    chatButton,
                                    const SizedBox(width: 8),
                                    muteButton,
                                    const SizedBox(width: 8),
                                    leaveButton,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isWideLayout && _isChatOpen && isRtl)
                  SizedBox(
                    width: 320,
                    child: ChatPanel(
                      isSidePanel: true,
                      onClose: () => _setChatPanelOpen(false),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
