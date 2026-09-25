import '../models/lesson.dart';

enum LessonStatus { past, now, next, future }

/// Портировано из Clock.java: статусы пар, отсчёт времени, форматирование.
class ClockLogic {
  /// 0=Вс, 1=Пн..6=Сб — совместимо с полем Lesson.day.
  static int todayDow(DateTime now) => now.weekday == DateTime.sunday ? 0 : now.weekday;

  static int nowMin(DateTime now) => now.hour * 60 + now.minute;
  static int nowSec(DateTime now) => now.hour * 3600 + now.minute * 60 + now.second;

  static int toMin(String t) {
    if (t.isEmpty) return -1;
    try {
      final p = t.replaceAll('.', ':').split(':');
      return int.parse(p[0].trim()) * 60 + int.parse(p[1].trim());
    } catch (_) {
      return -1;
    }
  }

  static int toSec(String t) {
    final m = toMin(t);
    return m < 0 ? -1 : m * 60;
  }

  static LessonStatus status(Lesson l, DateTime now) {
    final n = nowMin(now);
    final start = toMin(l.timeStart);
    final end = toMin(l.timeEnd);
    if (start < 0 || end < 0) return LessonStatus.future;
    if (n > end) return LessonStatus.past;
    if (n >= start) return LessonStatus.now;
    return LessonStatus.future;
  }

  /// Возвращает статус каждой пары дня; первая будущая помечается NEXT.
  static List<LessonStatus> assignStatuses(List<Lesson> lessons, DateTime now) {
    final out = List<LessonStatus>.filled(lessons.length, LessonStatus.future);
    var nextDone = false;
    for (var i = 0; i < lessons.length; i++) {
      final s = status(lessons[i], now);
      if (s == LessonStatus.future && !nextDone) {
        out[i] = LessonStatus.next;
        nextDone = true;
      } else {
        out[i] = s;
      }
    }
    return out;
  }

  static int secsToStart(Lesson l, DateTime now) => toSec(l.timeStart) - nowSec(now);
  static int secsToEnd(Lesson l, DateTime now) => toSec(l.timeEnd) - nowSec(now);
  static int minsToStart(Lesson l, DateTime now) => toMin(l.timeStart) - nowMin(now);

  static String countdown(int secs) {
    if (secs <= 0) return '00:00';
    final h = secs ~/ 3600, m = (secs % 3600) ~/ 60, s = secs % 60;
    return h > 0 ? '${_pad(h)}:${_pad(m)}:${_pad(s)}' : '${_pad(m)}:${_pad(s)}';
  }

  static String mins(int m) {
    if (m <= 0) return '0 мин';
    if (m < 60) return '$m мин';
    final h = m ~/ 60, mm = m % 60;
    return mm == 0 ? '$h ч' : '$h ч $mm мин';
  }

  static String _pad(int v) => v < 10 ? '0$v' : '$v';

  static const _months = [
    '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];
  static const _weekdays = [
    '', 'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье',
  ];

  static String todayStr(DateTime now) {
    final wd = _weekdays[now.weekday];
    final s = '$wd, ${now.day} ${_months[now.month]}';
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  static String dayName(int dow) {
    const n = ['', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
    return (dow >= 1 && dow <= 6) ? n[dow] : 'Воскресенье';
  }

  static String dayShort(int dow) {
    const s = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    return (dow >= 1 && dow <= 6) ? s[dow] : 'Вс';
  }
}
