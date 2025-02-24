import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData;

  ThemeProvider(this._themeData);

  ThemeData get themeData => _themeData;

  void setTheme(ThemeData theme) {
    _themeData = theme;
    notifyListeners();
  }
}

final ThemeData lightTheme = ThemeData.light().copyWith(
  primaryColor: const Color(0xFF075E54),
  colorScheme: ColorScheme.light(
    primary: const Color(0xFF075E54),
    secondary: const Color(0xFF25D366),
    background: const Color(0xFFECE5DD),
  ),
  scaffoldBackgroundColor: const Color(0xFFECE5DD),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF075E54),
    iconTheme: IconThemeData(color: Colors.white),
  ),
  iconTheme: const IconThemeData(color: Color(0xFF075E54)),
  textTheme: const TextTheme(
    titleLarge: TextStyle(color: Colors.white, fontSize: 20),
    bodyMedium: TextStyle(color: Colors.black),
  ),
);

final ThemeData darkTheme = ThemeData.dark().copyWith(
  primaryColor: const Color(0xFF075E54),
  colorScheme: ColorScheme.dark(
    primary: const Color(0xFF075E54),
    secondary: const Color(0xFF25D366),
    background: const Color(0xFF121212),
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF075E54),
    iconTheme: IconThemeData(color: Colors.white),
  ),
  iconTheme: const IconThemeData(color: Color(0xFF25D366)),
  textTheme: const TextTheme(
    titleLarge: TextStyle(color: Colors.white, fontSize: 20),
    bodyMedium: TextStyle(color: Colors.white),
  ),
);
