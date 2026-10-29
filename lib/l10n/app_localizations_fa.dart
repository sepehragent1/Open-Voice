// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'اوپن ویس';

  @override
  String get settings => 'تنظیمات';

  @override
  String get language => 'زبان';

  @override
  String get theme => 'پوسته';

  @override
  String get english => 'انگلیسی';

  @override
  String get persian => 'فارسی';

  @override
  String get systemDefault => 'پیش‌فرض سیستم';

  @override
  String get light => 'روشن';

  @override
  String get dark => 'تیره';

  @override
  String get settingsSubtitle => 'زبان و ظاهر دلخواه خود را انتخاب کنید.';

  @override
  String settingsSaveError(String error) {
    return 'ذخیره تنظیمات ممکن نیست: $error';
  }

  @override
  String requestFailed(String error) {
    return 'تکمیل درخواست ممکن نیست: $error';
  }

  @override
  String get connectionFailed =>
      'اتصال برقرار نشد: اتاق پیدا نشد یا نشانی IP نامعتبر است.';

  @override
  String hostingFailed(String error) {
    return 'راه‌اندازی سرور اتاق ممکن نیست: $error';
  }

  @override
  String microphoneFailed(String error) {
    return 'دسترسی به میکروفون ممکن نیست: $error';
  }

  @override
  String get microphoneUnavailable => 'میکروفون پیدا نشد یا دسترسی رد شده است';

  @override
  String get noLocalAddress =>
      'نشانی IPv4 محلی در دسترس نیست. به شبکه متصل شوید و دوباره تلاش کنید.';

  @override
  String get homeTagline => 'گفت‌وگوی صوتی، مستقیم.';

  @override
  String welcomeUser(String name) {
    return 'خوش آمدی، $name.';
  }

  @override
  String get homeDescription =>
      'اتاق بسازید یا با نشانی شبکه به اتاقی بپیوندید.';

  @override
  String get roomSettings => 'تنظیمات اتاق';

  @override
  String get hostIp => 'نشانی IP میزبان';

  @override
  String get hostIpHint => 'برای نمونه 192.168.1.10';

  @override
  String get port => 'درگاه';

  @override
  String get turnConfigs => 'تنظیمات TURN';

  @override
  String get noTurnConfigs =>
      'هنوز تنظیماتی وجود ندارد. به‌طور پیش‌فرض از STUN استفاده می‌شود.';

  @override
  String get addTurnConfig => 'افزودن تنظیم TURN';

  @override
  String get deleteSelectedTurnConfig => 'حذف تنظیم انتخاب‌شده TURN';

  @override
  String get showMore => 'نمایش بیشتر';

  @override
  String get showLess => 'نمایش کمتر';

  @override
  String get hostRoom => 'میزبانی اتاق';

  @override
  String get joinRoom => 'پیوستن به اتاق';

  @override
  String get starting => 'در حال شروع...';

  @override
  String get loading => 'در حال بارگذاری...';

  @override
  String get enterValidPort => 'درگاهی بین ۱ تا ۶۵۵۳۵ وارد کنید.';

  @override
  String get enterValidIpv4 =>
      'یک نشانی IPv4 معتبر وارد کنید؛ مانند 192.168.1.10.';

  @override
  String get joinRejected => 'درخواست پیوستن شما توسط میزبان رد شد.';

  @override
  String get systemNotificationJoinRequestTitle => 'درخواست ورود جدید';

  @override
  String systemNotificationJoinRequestBody(String name) {
    return '$name می‌خواهد به اتاق شما بپیوندد.';
  }

  @override
  String get systemNotificationJoinAcceptedTitle => 'درخواست شما تأیید شد';

  @override
  String systemNotificationJoinAcceptedBody(String room) {
    return 'شما به اتاق $room پیوستید.';
  }

  @override
  String get systemNotificationJoinRejectedTitle => 'درخواست ورود رد شد';

  @override
  String get systemNotificationJoinRejectedBody =>
      'میزبان درخواست پیوستن شما را رد کرد.';

  @override
  String couldNotLoadName(String error) {
    return 'بارگذاری نام ذخیره‌شده ممکن نیست: $error';
  }

  @override
  String couldNotLoadTurnConfigs(String error) {
    return 'بارگذاری تنظیمات TURN ممکن نیست: $error';
  }

  @override
  String couldNotSaveName(String error) {
    return 'ذخیره نام ممکن نیست: $error';
  }

  @override
  String couldNotSaveTurnConfig(String error) {
    return 'ذخیره تنظیم TURN ممکن نیست: $error';
  }

  @override
  String couldNotSelectTurnConfig(String error) {
    return 'انتخاب تنظیم TURN ممکن نیست: $error';
  }

  @override
  String get deleteTurnConfigTitle => 'تنظیم TURN حذف شود؟';

  @override
  String deleteTurnConfigConfirm(String name) {
    return '«$name» حذف شود؟ این کار برگشت‌پذیر نیست.';
  }

  @override
  String get cancel => 'لغو';

  @override
  String get delete => 'حذف';

  @override
  String get profileNamePrompt => 'نام شما چیست؟';

  @override
  String get displayName => 'نام نمایشی';

  @override
  String get save => 'ذخیره';

  @override
  String get nameLengthError => 'نامی بین ۱ تا ۴۰ نویسه وارد کنید.';

  @override
  String nameSaveError(String error) {
    return 'ذخیره نام ممکن نیست: $error';
  }

  @override
  String get turnConfigAddTitle => 'افزودن تنظیم TURN';

  @override
  String get turnConfigEditTitle => 'ویرایش تنظیم TURN';

  @override
  String get configName => 'نام تنظیم';

  @override
  String get configNameHint => 'سرور خانگی من';

  @override
  String get turnUrl => 'نشانی TURN';

  @override
  String get turnUrlHint => 'turn:1.2.3.4:5349';

  @override
  String get turnUsername => 'نام کاربری TURN';

  @override
  String get turnPassword => 'گذرواژه TURN';

  @override
  String get turnConfigValidation =>
      'همه موارد را با نشانی TURN و درگاه معتبر تکمیل کنید.';

  @override
  String get waitingApproval => 'در انتظار تأیید میزبان...';

  @override
  String get cancelRequest => 'لغو درخواست';

  @override
  String cancelRequestError(String error) {
    return 'لغو درخواست پیوستن ممکن نیست: $error';
  }

  @override
  String hostingOn(String ip, String port) {
    return 'میزبانی در $ip:$port';
  }

  @override
  String roomAt(String ip, String port) {
    return 'اتاق: $ip:$port';
  }

  @override
  String get youAreHosting => 'شما میزبان هستید';

  @override
  String get connected => 'متصل';

  @override
  String get connectionIssue => 'مشکل اتصال';

  @override
  String get connectionLostReconnecting =>
      'اتصال قطع شد. در حال اتصال دوباره...';

  @override
  String get reconnectFailed => 'اتصال دوباره برقرار نشد. از اتاق خارج شدید.';

  @override
  String get qualityStrong => 'قوی';

  @override
  String get qualityMedium => 'متوسط';

  @override
  String get qualityWeak => 'ضعیف';

  @override
  String shareRoom(String ip, String port) {
    return 'نشانی $ip:$port را با دیگران به اشتراک بگذارید.';
  }

  @override
  String youJoined(String ip, String port) {
    return 'به $ip:$port پیوستید.';
  }

  @override
  String get peopleInRoom => 'افراد حاضر در اتاق';

  @override
  String get waitingMembers => 'در انتظار اعضای اتاق';

  @override
  String get moderator => 'مدیر';

  @override
  String get inRoom => 'در اتاق';

  @override
  String get peerVolume => 'صدای هم‌اتاقی';

  @override
  String get audioDevices => 'دستگاه‌های صوتی';

  @override
  String get inputMicrophone => 'ورودی (میکروفون)';

  @override
  String get outputSpeaker => 'خروجی (بلندگو)';

  @override
  String get defaultDeviceSuffix => 'پیش‌فرض';

  @override
  String get refresh => 'تازه‌سازی فهرست دستگاه‌ها';

  @override
  String get noAudioDevices => 'دستگاه صوتی پیدا نشد.';

  @override
  String get disconnected => 'قطع‌شده';

  @override
  String kickPeerTooltip(String name) {
    return 'اخراج $name';
  }

  @override
  String wantsToJoin(String name) {
    return '$name می‌خواهد بپیوندد';
  }

  @override
  String get reject => 'رد';

  @override
  String get approve => 'تأیید';

  @override
  String get mute => 'بی‌صدا';

  @override
  String get unmute => 'فعال‌کردن صدا';

  @override
  String get leaveRoom => 'خروج از اتاق';

  @override
  String get confirmLeaveRoomTitle => 'خروج از اتاق؟';

  @override
  String get confirmLeaveRoomMessage =>
      'آیا مطمئن هستید که می‌خواهید از اتاق خارج شوید؟';

  @override
  String get roomClosed => 'میزبان اتاق را بسته است.';

  @override
  String get kickedFromRoom => 'میزبان شما را از اتاق اخراج کرد.';

  @override
  String couldNotChangeMic(String error) {
    return 'تغییر وضعیت میکروفون ممکن نیست: $error';
  }

  @override
  String couldNotLeaveRoom(String error) {
    return 'خروج صحیح از اتاق ممکن نیست: $error';
  }

  @override
  String couldNotApprove(String error) {
    return 'تأیید درخواست پیوستن ممکن نیست: $error';
  }

  @override
  String couldNotReject(String error) {
    return 'رد درخواست پیوستن ممکن نیست: $error';
  }

  @override
  String kickTitle(String name) {
    return '$name اخراج شود؟';
  }

  @override
  String kickConfirm(String name) {
    return 'آیا مطمئن هستید که می‌خواهید $name را از اتاق خارج کنید؟';
  }

  @override
  String get kick => 'اخراج';

  @override
  String couldNotKick(String name, String error) {
    return 'اخراج $name ممکن نیست: $error';
  }

  @override
  String couldNotReleaseResources(String error) {
    return 'آزادسازی منابع اتاق ممکن نیست: $error';
  }

  @override
  String get roomChat => 'گفت‌وگوی اتاق';

  @override
  String get youWereMentioned => 'شما را نام بردند';

  @override
  String get closeChat => 'بستن گفت‌وگو';

  @override
  String get noChatMessages => 'هنوز پیامی نیست. سلام کنید!';

  @override
  String get typeMessage => 'پیامی بنویسید';

  @override
  String get sendMessage => 'ارسال پیام';

  @override
  String get addEmoji => 'افزودن شکلک';

  @override
  String couldNotSendChatMessage(String error) {
    return 'ارسال پیام ممکن نیست: $error';
  }
}
