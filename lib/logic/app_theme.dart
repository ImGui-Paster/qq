import 'package:flutter/material.dart';

/// Палитра приложения — портирована из Theme.java 1:1.
/// Оригинальное Android-приложение всегда использует единый тёмный дизайн
/// (фон #0D0D0D на главном экране, карточки #181818/#242422), поэтому
/// здесь тема зафиксирована на тёмной — без переключения по системной теме,
/// как и в исходном приложении.
class AppTheme {
  static const Color accent = Color(0xFFC96442);

  // Тёмная палитра (единственная используемая)
  static const Color dBg = Color(0xFF0D0D0D);
  static const Color dHeader = Color(0xFF141414);
  static const Color dCard = Color(0xFF181818);
  static const Color dSurface = Color(0xFF2E2E2B);
  static const Color dText = Color(0xFFEEEEEE);
  static const Color dTextSec = Color(0xFF9C9C96);
  static const Color dTextHint = Color(0xFF66665F);
  static const Color dDivider = Color(0xFF252525);
  static const Color dNowBg = Color(0xFF2A241C);
  static const Color dNextBg = Color(0xFF1A1A18);

  // Оставлены для мест, где ещё используется адаптация (сейчас не задействовано).
  static const Color lBg = Color(0xFFFAFAF7);
  static const Color lCard = Color(0xFFFFFFFF);
  static const Color lSurface = Color(0xFFF0F0EC);
  static const Color lText = Color(0xFF2B2B27);
  static const Color lTextSec = Color(0xFF767670);
  static const Color lTextHint = Color(0xFFAFAFA6);
  static const Color lNowBg = Color(0xFFFBEFE6);
  static const Color lNextBg = Color(0xFFF2F2ED);

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: dBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
        surface: dCard,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: dHeader,
        foregroundColor: dText,
        elevation: 3,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: dCard),
      popupMenuTheme: const PopupMenuThemeData(color: dCard),
      useMaterial3: true,
      fontFamily: '.SF Pro Text',
    );
  }
}
