import 'package:flutter/material.dart';
import 'logic/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const CA125App());
}

class CA125App extends StatelessWidget {
  const CA125App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CA125',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
