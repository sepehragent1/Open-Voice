import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { system, english, persian }

enum AppTheme { system, light, dark }

class AppSettings extends ChangeNotifier {
  AppSettings._(this._preferences, this._language, this._theme);

  final SharedPreferences _preferences;
  AppLanguage _language;
  AppTheme _theme;

  AppLanguage get language => _language;
  AppTheme get theme => _theme;
  String? get audioInputDeviceId =>
      _preferences.getString('audio_input_device_id');
  String? get audioOutputDeviceId =>
      _preferences.getString('audio_output_device_id');

  Locale? get locale => switch (_language) {
    AppLanguage.system => null,
    AppLanguage.english => const Locale('en'),
    AppLanguage.persian => const Locale('fa'),
  };

  ThemeMode get themeMode => switch (_theme) {
    AppTheme.system => ThemeMode.system,
    AppTheme.light => ThemeMode.light,
    AppTheme.dark => ThemeMode.dark,
  };

  static Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    return AppSettings._(
      preferences,
      AppLanguage.values.firstWhere(
        (value) => value.name == preferences.getString('app_language'),
        orElse: () => AppLanguage.system,
      ),
      AppTheme.values.firstWhere(
        (value) => value.name == preferences.getString('app_theme'),
        orElse: () => AppTheme.system,
      ),
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    final saved = await _preferences.setString('app_language', language.name);
    if (!saved) throw StateError('The language preference could not be saved.');
    _language = language;
    notifyListeners();
  }

  Future<void> setTheme(AppTheme theme) async {
    final saved = await _preferences.setString('app_theme', theme.name);
    if (!saved) throw StateError('The theme preference could not be saved.');
    _theme = theme;
    notifyListeners();
  }

  Future<void> setAudioInputDeviceId(String? deviceId) async {
    final saved = deviceId == null || deviceId.isEmpty
        ? await _preferences.remove('audio_input_device_id')
        : await _preferences.setString('audio_input_device_id', deviceId);
    if (!saved) {
      throw StateError('The microphone preference could not be saved.');
    }
    notifyListeners();
  }

  Future<void> setAudioOutputDeviceId(String? deviceId) async {
    final saved = deviceId == null || deviceId.isEmpty
        ? await _preferences.remove('audio_output_device_id')
        : await _preferences.setString('audio_output_device_id', deviceId);
    if (!saved) {
      throw StateError('The speaker preference could not be saved.');
    }
    notifyListeners();
  }
}
