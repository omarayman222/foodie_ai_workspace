import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier._() : super(ThemeMode.light) { _init(); }
  static final ThemeNotifier instance = ThemeNotifier._();

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool('dark_mode') == true ? ThemeMode.dark : ThemeMode.light;
  }

  bool get isDark => value == ThemeMode.dark;

  Future<void> toggle() async {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDark);
  }
}
