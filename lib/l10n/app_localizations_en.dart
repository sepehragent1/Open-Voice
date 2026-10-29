// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Open Voice';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get english => 'English';

  @override
  String get persian => 'Persian (فارسی)';

  @override
  String get systemDefault => 'System default';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get settingsSubtitle =>
      'Choose your preferred language and appearance.';

  @override
  String settingsSaveError(String error) {
    return 'Could not save settings: $error';
  }

  @override
  String requestFailed(String error) {
    return 'Could not complete the request: $error';
  }

  @override
  String get connectionFailed =>
      'Connection failed: Room not found or invalid IP.';

  @override
  String hostingFailed(String error) {
    return 'Could not start the room server: $error';
  }

  @override
  String microphoneFailed(String error) {
    return 'Could not access the microphone: $error';
  }

  @override
  String get microphoneUnavailable => 'Microphone not found or access denied';

  @override
  String get noLocalAddress =>
      'No local IPv4 address is available. Connect to a network and try again.';

  @override
  String get homeTagline => 'Voice, directly.';

  @override
  String welcomeUser(String name) {
    return 'Welcome, $name.';
  }

  @override
  String get homeDescription =>
      'Host a room or join one using its network address.';

  @override
  String get roomSettings => 'Room settings';

  @override
  String get hostIp => 'Host IP';

  @override
  String get hostIpHint => 'e.g. 192.168.1.10';

  @override
  String get port => 'Port';

  @override
  String get turnConfigs => 'TURN Configs';

  @override
  String get noTurnConfigs =>
      'No configurations yet. STUN will be used by default.';

  @override
  String get addTurnConfig => 'Add TURN Config';

  @override
  String get deleteSelectedTurnConfig => 'Delete selected TURN config';

  @override
  String get showMore => 'Show More';

  @override
  String get showLess => 'Show Less';

  @override
  String get hostRoom => 'Host a Room';

  @override
  String get joinRoom => 'Join a Room';

  @override
  String get starting => 'Starting...';

  @override
  String get loading => 'Loading...';

  @override
  String get enterValidPort => 'Enter a port between 1 and 65535.';

  @override
  String get enterValidIpv4 =>
      'Enter a valid IPv4 address, such as 192.168.1.10.';

  @override
  String get joinRejected => 'Your request to join was rejected by the host.';

  @override
  String get systemNotificationJoinRequestTitle => 'New join request';

  @override
  String systemNotificationJoinRequestBody(String name) {
    return '$name wants to join your room.';
  }

  @override
  String get systemNotificationJoinAcceptedTitle => 'Join request accepted';

  @override
  String systemNotificationJoinAcceptedBody(String room) {
    return 'You joined $room.';
  }

  @override
  String get systemNotificationJoinRejectedTitle => 'Join request rejected';

  @override
  String get systemNotificationJoinRejectedBody =>
      'Your request to join was rejected.';

  @override
  String couldNotLoadName(String error) {
    return 'Could not load your saved name: $error';
  }

  @override
  String couldNotLoadTurnConfigs(String error) {
    return 'Could not load TURN configurations: $error';
  }

  @override
  String couldNotSaveName(String error) {
    return 'Could not save your name: $error';
  }

  @override
  String couldNotSaveTurnConfig(String error) {
    return 'Could not save TURN configuration: $error';
  }

  @override
  String couldNotSelectTurnConfig(String error) {
    return 'Could not select TURN configuration: $error';
  }

  @override
  String get deleteTurnConfigTitle => 'Delete TURN Config?';

  @override
  String deleteTurnConfigConfirm(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get profileNamePrompt => 'What\'s your name?';

  @override
  String get displayName => 'Display name';

  @override
  String get save => 'Save';

  @override
  String get nameLengthError => 'Enter a name of 1 to 40 characters.';

  @override
  String nameSaveError(String error) {
    return 'Could not save your name: $error';
  }

  @override
  String get turnConfigAddTitle => 'Add TURN Config';

  @override
  String get turnConfigEditTitle => 'Edit TURN Config';

  @override
  String get configName => 'Config Name';

  @override
  String get configNameHint => 'My Home Server';

  @override
  String get turnUrl => 'TURN URL';

  @override
  String get turnUrlHint => 'turn:1.2.3.4:5349';

  @override
  String get turnUsername => 'TURN Username';

  @override
  String get turnPassword => 'TURN Password';

  @override
  String get turnConfigValidation =>
      'Complete all fields with a valid TURN URL and port.';

  @override
  String get waitingApproval => 'Waiting for host approval...';

  @override
  String get cancelRequest => 'Cancel Request';

  @override
  String cancelRequestError(String error) {
    return 'Could not cancel the join request: $error';
  }

  @override
  String hostingOn(String ip, String port) {
    return 'Hosting on $ip:$port';
  }

  @override
  String roomAt(String ip, String port) {
    return 'Room: $ip:$port';
  }

  @override
  String get youAreHosting => 'You are hosting';

  @override
  String get connected => 'Connected';

  @override
  String get connectionIssue => 'Connection issue';

  @override
  String get connectionLostReconnecting => 'Connection lost. Reconnecting...';

  @override
  String get reconnectFailed => 'Could not reconnect. You have left the room.';

  @override
  String get qualityStrong => 'Strong';

  @override
  String get qualityMedium => 'Medium';

  @override
  String get qualityWeak => 'Weak';

  @override
  String shareRoom(String ip, String port) {
    return 'Share $ip:$port with others.';
  }

  @override
  String youJoined(String ip, String port) {
    return 'You joined $ip:$port.';
  }

  @override
  String get peopleInRoom => 'People in this room';

  @override
  String get waitingMembers => 'Waiting for room members';

  @override
  String get moderator => 'Moderator';

  @override
  String get inRoom => 'In the room';

  @override
  String get peerVolume => 'Peer volume';

  @override
  String get audioDevices => 'Audio devices';

  @override
  String get inputMicrophone => 'Input (Microphone)';

  @override
  String get outputSpeaker => 'Output (Speaker)';

  @override
  String get defaultDeviceSuffix => 'Default';

  @override
  String get refresh => 'Refresh device list';

  @override
  String get noAudioDevices => 'No audio devices found.';

  @override
  String get disconnected => 'Disconnected';

  @override
  String kickPeerTooltip(String name) {
    return 'Kick $name';
  }

  @override
  String wantsToJoin(String name) {
    return '$name wants to join';
  }

  @override
  String get reject => 'Reject';

  @override
  String get approve => 'Approve';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get leaveRoom => 'Leave Room';

  @override
  String get confirmLeaveRoomTitle => 'Leave room?';

  @override
  String get confirmLeaveRoomMessage =>
      'Are you sure you want to leave the room?';

  @override
  String get roomClosed => 'The host has closed the room.';

  @override
  String get kickedFromRoom =>
      'You have been kicked from the room by the host.';

  @override
  String couldNotChangeMic(String error) {
    return 'Could not change microphone state: $error';
  }

  @override
  String couldNotLeaveRoom(String error) {
    return 'Could not leave the room cleanly: $error';
  }

  @override
  String couldNotApprove(String error) {
    return 'Could not approve join request: $error';
  }

  @override
  String couldNotReject(String error) {
    return 'Could not reject join request: $error';
  }

  @override
  String kickTitle(String name) {
    return 'Kick $name?';
  }

  @override
  String kickConfirm(String name) {
    return 'Are you sure you want to remove $name from this room?';
  }

  @override
  String get kick => 'Kick';

  @override
  String couldNotKick(String name, String error) {
    return 'Could not kick $name: $error';
  }

  @override
  String couldNotReleaseResources(String error) {
    return 'Could not release room resources: $error';
  }

  @override
  String get roomChat => 'Room chat';

  @override
  String get youWereMentioned => 'You were mentioned';

  @override
  String get closeChat => 'Close chat';

  @override
  String get noChatMessages => 'No messages yet. Say hello!';

  @override
  String get typeMessage => 'Type a message';

  @override
  String get sendMessage => 'Send message';

  @override
  String get addEmoji => 'Add emoji';

  @override
  String couldNotSendChatMessage(String error) {
    return 'Could not send chat message: $error';
  }
}
