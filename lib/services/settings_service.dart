import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _keyDarkMode = 'is_dark_mode';
  static const String _keyShowHelp = 'show_help_legends';

  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> showHelpLegends = ValueNotifier<bool>(true);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = prefs.getBool(_keyDarkMode) ?? false;
    showHelpLegends.value = prefs.getBool(_keyShowHelp) ?? true;
  }

  static Future<void> toggleDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = !isDarkMode.value;
    await prefs.setBool(_keyDarkMode, isDarkMode.value);
  }

  static Future<void> toggleHelpLegends() async {
    final prefs = await SharedPreferences.getInstance();
    showHelpLegends.value = !showHelpLegends.value;
    await prefs.setBool(_keyShowHelp, showHelpLegends.value);
  }
}
