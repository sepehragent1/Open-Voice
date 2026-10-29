import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Voice'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @persian.
  ///
  /// In en, this message translates to:
  /// **'Persian (فارسی)'**
  String get persian;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language and appearance.'**
  String get settingsSubtitle;

  /// No description provided for @settingsSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save settings: {error}'**
  String settingsSaveError(String error);

  /// No description provided for @requestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the request: {error}'**
  String requestFailed(String error);

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: Room not found or invalid IP.'**
  String get connectionFailed;

  /// No description provided for @hostingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the room server: {error}'**
  String hostingFailed(String error);

  /// No description provided for @microphoneFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not access the microphone: {error}'**
  String microphoneFailed(String error);

  /// No description provided for @microphoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Microphone not found or access denied'**
  String get microphoneUnavailable;

  /// No description provided for @noLocalAddress.
  ///
  /// In en, this message translates to:
  /// **'No local IPv4 address is available. Connect to a network and try again.'**
  String get noLocalAddress;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Voice, directly.'**
  String get homeTagline;

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}.'**
  String welcomeUser(String name);

  /// No description provided for @homeDescription.
  ///
  /// In en, this message translates to:
  /// **'Host a room or join one using its network address.'**
  String get homeDescription;

  /// No description provided for @roomSettings.
  ///
  /// In en, this message translates to:
  /// **'Room settings'**
  String get roomSettings;

  /// No description provided for @hostIp.
  ///
  /// In en, this message translates to:
  /// **'Host IP'**
  String get hostIp;

  /// No description provided for @hostIpHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.10'**
  String get hostIpHint;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @turnConfigs.
  ///
  /// In en, this message translates to:
  /// **'TURN Configs'**
  String get turnConfigs;

  /// No description provided for @noTurnConfigs.
  ///
  /// In en, this message translates to:
  /// **'No configurations yet. STUN will be used by default.'**
  String get noTurnConfigs;

  /// No description provided for @addTurnConfig.
  ///
  /// In en, this message translates to:
  /// **'Add TURN Config'**
  String get addTurnConfig;

  /// No description provided for @deleteSelectedTurnConfig.
  ///
  /// In en, this message translates to:
  /// **'Delete selected TURN config'**
  String get deleteSelectedTurnConfig;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show More'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show Less'**
  String get showLess;

  /// No description provided for @hostRoom.
  ///
  /// In en, this message translates to:
  /// **'Host a Room'**
  String get hostRoom;

  /// No description provided for @joinRoom.
  ///
  /// In en, this message translates to:
  /// **'Join a Room'**
  String get joinRoom;

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get starting;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @enterValidPort.
  ///
  /// In en, this message translates to:
  /// **'Enter a port between 1 and 65535.'**
  String get enterValidPort;

  /// No description provided for @enterValidIpv4.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid IPv4 address, such as 192.168.1.10.'**
  String get enterValidIpv4;

  /// No description provided for @joinRejected.
  ///
  /// In en, this message translates to:
  /// **'Your request to join was rejected by the host.'**
  String get joinRejected;

  /// No description provided for @systemNotificationJoinRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'New join request'**
  String get systemNotificationJoinRequestTitle;

  /// No description provided for @systemNotificationJoinRequestBody.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to join your room.'**
  String systemNotificationJoinRequestBody(String name);

  /// No description provided for @systemNotificationJoinAcceptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Join request accepted'**
  String get systemNotificationJoinAcceptedTitle;

  /// No description provided for @systemNotificationJoinAcceptedBody.
  ///
  /// In en, this message translates to:
  /// **'You joined {room}.'**
  String systemNotificationJoinAcceptedBody(String room);

  /// No description provided for @systemNotificationJoinRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Join request rejected'**
  String get systemNotificationJoinRejectedTitle;

  /// No description provided for @systemNotificationJoinRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your request to join was rejected.'**
  String get systemNotificationJoinRejectedBody;

  /// No description provided for @couldNotLoadName.
  ///
  /// In en, this message translates to:
  /// **'Could not load your saved name: {error}'**
  String couldNotLoadName(String error);

  /// No description provided for @couldNotLoadTurnConfigs.
  ///
  /// In en, this message translates to:
  /// **'Could not load TURN configurations: {error}'**
  String couldNotLoadTurnConfigs(String error);

  /// No description provided for @couldNotSaveName.
  ///
  /// In en, this message translates to:
  /// **'Could not save your name: {error}'**
  String couldNotSaveName(String error);

  /// No description provided for @couldNotSaveTurnConfig.
  ///
  /// In en, this message translates to:
  /// **'Could not save TURN configuration: {error}'**
  String couldNotSaveTurnConfig(String error);

  /// No description provided for @couldNotSelectTurnConfig.
  ///
  /// In en, this message translates to:
  /// **'Could not select TURN configuration: {error}'**
  String couldNotSelectTurnConfig(String error);

  /// No description provided for @deleteTurnConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete TURN Config?'**
  String get deleteTurnConfigTitle;

  /// No description provided for @deleteTurnConfigConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String deleteTurnConfigConfirm(String name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @profileNamePrompt.
  ///
  /// In en, this message translates to:
  /// **'What\'s your name?'**
  String get profileNamePrompt;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @nameLengthError.
  ///
  /// In en, this message translates to:
  /// **'Enter a name of 1 to 40 characters.'**
  String get nameLengthError;

  /// No description provided for @nameSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your name: {error}'**
  String nameSaveError(String error);

  /// No description provided for @turnConfigAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add TURN Config'**
  String get turnConfigAddTitle;

  /// No description provided for @turnConfigEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit TURN Config'**
  String get turnConfigEditTitle;

  /// No description provided for @configName.
  ///
  /// In en, this message translates to:
  /// **'Config Name'**
  String get configName;

  /// No description provided for @configNameHint.
  ///
  /// In en, this message translates to:
  /// **'My Home Server'**
  String get configNameHint;

  /// No description provided for @turnUrl.
  ///
  /// In en, this message translates to:
  /// **'TURN URL'**
  String get turnUrl;

  /// No description provided for @turnUrlHint.
  ///
  /// In en, this message translates to:
  /// **'turn:1.2.3.4:5349'**
  String get turnUrlHint;

  /// No description provided for @turnUsername.
  ///
  /// In en, this message translates to:
  /// **'TURN Username'**
  String get turnUsername;

  /// No description provided for @turnPassword.
  ///
  /// In en, this message translates to:
  /// **'TURN Password'**
  String get turnPassword;

  /// No description provided for @turnConfigValidation.
  ///
  /// In en, this message translates to:
  /// **'Complete all fields with a valid TURN URL and port.'**
  String get turnConfigValidation;

  /// No description provided for @waitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for host approval...'**
  String get waitingApproval;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel Request'**
  String get cancelRequest;

  /// No description provided for @cancelRequestError.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel the join request: {error}'**
  String cancelRequestError(String error);

  /// No description provided for @hostingOn.
  ///
  /// In en, this message translates to:
  /// **'Hosting on {ip}:{port}'**
  String hostingOn(String ip, String port);

  /// No description provided for @roomAt.
  ///
  /// In en, this message translates to:
  /// **'Room: {ip}:{port}'**
  String roomAt(String ip, String port);

  /// No description provided for @youAreHosting.
  ///
  /// In en, this message translates to:
  /// **'You are hosting'**
  String get youAreHosting;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @connectionIssue.
  ///
  /// In en, this message translates to:
  /// **'Connection issue'**
  String get connectionIssue;

  /// No description provided for @connectionLostReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Connection lost. Reconnecting...'**
  String get connectionLostReconnecting;

  /// No description provided for @reconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reconnect. You have left the room.'**
  String get reconnectFailed;

  /// No description provided for @qualityStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get qualityStrong;

  /// No description provided for @qualityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get qualityMedium;

  /// No description provided for @qualityWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get qualityWeak;

  /// No description provided for @shareRoom.
  ///
  /// In en, this message translates to:
  /// **'Share {ip}:{port} with others.'**
  String shareRoom(String ip, String port);

  /// No description provided for @youJoined.
  ///
  /// In en, this message translates to:
  /// **'You joined {ip}:{port}.'**
  String youJoined(String ip, String port);

  /// No description provided for @peopleInRoom.
  ///
  /// In en, this message translates to:
  /// **'People in this room'**
  String get peopleInRoom;

  /// No description provided for @waitingMembers.
  ///
  /// In en, this message translates to:
  /// **'Waiting for room members'**
  String get waitingMembers;

  /// No description provided for @moderator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get moderator;

  /// No description provided for @inRoom.
  ///
  /// In en, this message translates to:
  /// **'In the room'**
  String get inRoom;

  /// No description provided for @peerVolume.
  ///
  /// In en, this message translates to:
  /// **'Peer volume'**
  String get peerVolume;

  /// No description provided for @audioDevices.
  ///
  /// In en, this message translates to:
  /// **'Audio devices'**
  String get audioDevices;

  /// No description provided for @inputMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Input (Microphone)'**
  String get inputMicrophone;

  /// No description provided for @outputSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Output (Speaker)'**
  String get outputSpeaker;

  /// No description provided for @defaultDeviceSuffix.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultDeviceSuffix;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh device list'**
  String get refresh;

  /// No description provided for @noAudioDevices.
  ///
  /// In en, this message translates to:
  /// **'No audio devices found.'**
  String get noAudioDevices;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @kickPeerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Kick {name}'**
  String kickPeerTooltip(String name);

  /// No description provided for @wantsToJoin.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to join'**
  String wantsToJoin(String name);

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @leaveRoom.
  ///
  /// In en, this message translates to:
  /// **'Leave Room'**
  String get leaveRoom;

  /// No description provided for @confirmLeaveRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave room?'**
  String get confirmLeaveRoomTitle;

  /// No description provided for @confirmLeaveRoomMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave the room?'**
  String get confirmLeaveRoomMessage;

  /// No description provided for @roomClosed.
  ///
  /// In en, this message translates to:
  /// **'The host has closed the room.'**
  String get roomClosed;

  /// No description provided for @kickedFromRoom.
  ///
  /// In en, this message translates to:
  /// **'You have been kicked from the room by the host.'**
  String get kickedFromRoom;

  /// No description provided for @couldNotChangeMic.
  ///
  /// In en, this message translates to:
  /// **'Could not change microphone state: {error}'**
  String couldNotChangeMic(String error);

  /// No description provided for @couldNotLeaveRoom.
  ///
  /// In en, this message translates to:
  /// **'Could not leave the room cleanly: {error}'**
  String couldNotLeaveRoom(String error);

  /// No description provided for @couldNotApprove.
  ///
  /// In en, this message translates to:
  /// **'Could not approve join request: {error}'**
  String couldNotApprove(String error);

  /// No description provided for @couldNotReject.
  ///
  /// In en, this message translates to:
  /// **'Could not reject join request: {error}'**
  String couldNotReject(String error);

  /// No description provided for @kickTitle.
  ///
  /// In en, this message translates to:
  /// **'Kick {name}?'**
  String kickTitle(String name);

  /// No description provided for @kickConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name} from this room?'**
  String kickConfirm(String name);

  /// No description provided for @kick.
  ///
  /// In en, this message translates to:
  /// **'Kick'**
  String get kick;

  /// No description provided for @couldNotKick.
  ///
  /// In en, this message translates to:
  /// **'Could not kick {name}: {error}'**
  String couldNotKick(String name, String error);

  /// No description provided for @couldNotReleaseResources.
  ///
  /// In en, this message translates to:
  /// **'Could not release room resources: {error}'**
  String couldNotReleaseResources(String error);

  /// No description provided for @roomChat.
  ///
  /// In en, this message translates to:
  /// **'Room chat'**
  String get roomChat;

  /// No description provided for @youWereMentioned.
  ///
  /// In en, this message translates to:
  /// **'You were mentioned'**
  String get youWereMentioned;

  /// No description provided for @closeChat.
  ///
  /// In en, this message translates to:
  /// **'Close chat'**
  String get closeChat;

  /// No description provided for @noChatMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello!'**
  String get noChatMessages;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get typeMessage;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessage;

  /// No description provided for @addEmoji.
  ///
  /// In en, this message translates to:
  /// **'Add emoji'**
  String get addEmoji;

  /// No description provided for @couldNotSendChatMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not send chat message: {error}'**
  String couldNotSendChatMessage(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
