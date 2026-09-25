import 'package:shared_preferences/shared_preferences.dart';
import '../models/lesson.dart';

/// Расписание звонков колледжа. Портировано 1:1 из Bells.java.
class Bells {
  static const int mon = 0;
  static const int tueFri = 1;
  static const int sat = 2;

  // [день-режим][пара][0=начало,1=конец]
  static const List<List<List<String>>> _def = [
    // Понедельник
    [
      ['08:00', '08:55'],
      ['09:00', '10:30'],
      ['10:40', '12:10'],
      ['12:50', '14:20'],
      ['14:30', '16:00'],
      ['16:05', '17:35'],
    ],
    // Вторник–Пятница
    [
      ['08:15', '09:45'],
      ['09:55', '11:25'],
      ['12:05', '13:35'],
      ['13:45', '15:15'],
      ['15:25', '16:55'],
      ['17:00', '18:30'],
    ],
    // Суббота
    [
      ['08:15', '09:15'],
      ['09:25', '10:25'],
      ['10:35', '11:35'],
      ['11:45', '12:45'],
      ['12:55', '13:55'],
      ['14:05', '15:05'],
    ],
  ];

  // Перемены в минутах после пары (индекс = номер_пары - 1)
  static const List<List<int>> _breaks = [
    [5, 10, 40, 10, 5, 0],
    [10, 40, 10, 10, 5, 0],
    [10, 10, 10, 10, 10, 0],
  ];

  static int modeFor(int dayOfWeek) {
    if (dayOfWeek == 1) return mon;
    if (dayOfWeek == 6) return sat;
    return tueFri;
  }

  static String defStart(int mode, int idx) => _def[mode][idx][0];
  static String defEnd(int mode, int idx) => _def[mode][idx][1];

  static int breakAfter(int num, int mode) {
    final idx = num - 1;
    if (idx < 0 || idx >= 6 || mode < 0 || mode > 2) return 0;
    return _breaks[mode][idx];
  }

  static String breakLabel(int afterNum, int dayOfWeek) {
    final mins = breakAfter(afterNum, modeFor(dayOfWeek));
    if (mins <= 0) return '';
    return mins >= 30 ? 'Большая перемена · $mins мин' : 'Перемена · $mins мин';
  }

  /// Заполняет время начала/конца пары, если оно не задано явно (например
  /// после OCR-импорта, где время часто не распознаётся надёжно).
  static Future<void> applyTo(Lesson l) async {
    final mode = modeFor(l.day);
    final n = l.num;
    if (n < 1 || n > 6) return;
    final sp = await SharedPreferences.getInstance();
    if (l.timeStart.isEmpty) {
      l.timeStart = sp.getString(_key(mode, n - 1, true)) ?? defStart(mode, n - 1);
    }
    if (l.timeEnd.isEmpty) {
      l.timeEnd = sp.getString(_key(mode, n - 1, false)) ?? defEnd(mode, n - 1);
    }
  }

  static String _key(int m, int i, bool s) => 'bells_m${m}_$i${s ? 's' : 'e'}';

  /// Текущее (пользовательское либо дефолтное) время начала пары.
  static Future<String> start(int mode, int idx) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_key(mode, idx, true)) ?? defStart(mode, idx);
  }

  /// Текущее (пользовательское либо дефолтное) время конца пары.
  static Future<String> end(int mode, int idx) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_key(mode, idx, false)) ?? defEnd(mode, idx);
  }

  /// Сохраняет пользовательское время пары (используется редактором звонков).
  static Future<void> set(int mode, int idx, String startTime, String endTime) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key(mode, idx, true), startTime);
    await sp.setString(_key(mode, idx, false), endTime);
  }

  /// Сбрасывает все пользовательские правки звонков к значениям по умолчанию.
  static Future<void> reset() async {
    final sp = await SharedPreferences.getInstance();
    for (var m = 0; m < 3; m++) {
      for (var i = 0; i < 6; i++) {
        await sp.remove(_key(m, i, true));
        await sp.remove(_key(m, i, false));
      }
    }
  }
}
