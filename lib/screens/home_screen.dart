import 'dart:async';
import 'package:flutter/material.dart';
import '../logic/app_theme.dart';
import '../logic/bells.dart';
import '../logic/clock_logic.dart';
import '../logic/db.dart';
import '../logic/prefs.dart';
import '../models/homework.dart';
import '../models/lesson.dart';
import 'bell_editor_screen.dart';
import 'exams_screen.dart';
import 'homework_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DB _db = DB();
  late final PageController _pageController;
  int _selDay = 1; // 1..6, Пн..Сб
  int _lastSync = 0;
  Timer? _tick;

  // Кэш пар/статусов по дню, чтобы свайп не мигал загрузкой.
  final Map<int, List<Lesson>> _lessonsByDay = {};
  final Map<int, List<LessonStatus>> _statusesByDay = {};
  final Set<int> _loadingDays = {};

  @override
  void initState() {
    super.initState();
    _selDay = ClockLogic.todayDow(DateTime.now());
    if (_selDay == 0) _selDay = 1;
    _pageController = PageController(initialPage: _selDay - 1);
    _loadHeader();
    _loadDay(_selDay);
    _startTick();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadHeader() async {
    _lastSync = await Prefs.getLastSync();
    if (mounted) setState(() {});
  }

  Future<void> _loadDay(int day) async {
    if (_loadingDays.contains(day)) return;
    _loadingDays.add(day);
    final lessons = await _db.lessonsForDay(day);
    for (final l in lessons) {
      await Bells.applyTo(l);
    }
    final now = DateTime.now();
    final isToday = day == ClockLogic.todayDow(now);
    final statuses = isToday
        ? ClockLogic.assignStatuses(lessons, now)
        : List<LessonStatus>.filled(lessons.length, LessonStatus.future);

    _loadingDays.remove(day);
    if (!mounted) return;
    setState(() {
      _lessonsByDay[day] = lessons;
      _statusesByDay[day] = statuses;
    });
  }

  Future<void> _reloadAll() async {
    _lessonsByDay.clear();
    _statusesByDay.clear();
    await _loadDay(_selDay);
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final today = ClockLogic.todayDow(now);
      final lessons = _lessonsByDay[today];
      if (lessons == null) return;
      setState(() {
        _statusesByDay[today] = ClockLogic.assignStatuses(lessons, now);
      });
    });
  }

  void _onPageChanged(int index) {
    final day = index + 1;
    setState(() => _selDay = day);
    _loadDay(day);
  }

  // Ближайшая пара сегодня для отсчёта (текущая или следующая).
  ({Lesson lesson, bool toEnd})? _timerTarget() {
    final today = ClockLogic.todayDow(DateTime.now());
    final lessons = _lessonsByDay[today];
    final statuses = _statusesByDay[today];
    if (lessons == null || statuses == null) return null;
    for (var i = 0; i < lessons.length; i++) {
      if (statuses[i] == LessonStatus.now) return (lesson: lessons[i], toEnd: true);
      if (statuses[i] == LessonStatus.next) return (lesson: lessons[i], toEnd: false);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = ClockLogic.todayDow(now);
    final target = _timerTarget();
    final hasLessonsToday = (_lessonsByDay[today] ?? []).isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.dBg,
      appBar: AppBar(
        backgroundColor: AppTheme.dHeader,
        elevation: 3,
        title: Text(ClockLogic.todayStr(now)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              Widget? screen;
              if (v == 'hw') screen = const HomeworkScreen();
              if (v == 'exams') screen = const ExamsScreen();
              if (v == 'bells') screen = const BellEditorScreen();
              if (v == 'settings') screen = const SettingsScreen();
              if (screen != null) {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
                _loadHeader();
                _reloadAll();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'hw', child: Text('Домашние задания')),
              PopupMenuItem(value: 'exams', child: Text('Экзамены')),
              PopupMenuItem(value: 'bells', child: Text('Расписание звонков')),
              PopupMenuItem(value: 'settings', child: Text('Настройки')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_staleLabel() != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF332B1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_staleLabel()!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 12)),
            ),
          _buildCountdownHeader(target, hasLessonsToday),
          _buildTabs(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: 6,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final day = index + 1;
                return _buildDayPage(day);
              },
            ),
          ),
        ],
      ),
    );
  }

  String? _staleLabel() {
    if (_lastSync == 0) return 'Расписание ещё не загружено — откройте настройки';
    final ageMs = DateTime.now().millisecondsSinceEpoch - _lastSync;
    const staleMs = 24 * 60 * 60 * 1000;
    if (ageMs > staleMs) {
      final days = ageMs ~/ (24 * 60 * 60 * 1000);
      final label = days < 1 ? 'более суток' : (days == 1 ? '1 день' : '$days дн.');
      return 'Данные не обновлялись $label — возможны неточности';
    }
    return null;
  }

  Widget _buildCountdownHeader(({Lesson lesson, bool toEnd})? target, bool hasLessonsToday) {
    String label;
    String value;
    Color valueColor = AppTheme.accent;

    if (target == null) {
      label = hasLessonsToday ? 'Все пары завершены' : '';
      value = hasLessonsToday ? '✓' : '--:--';
      valueColor = AppTheme.dTextHint;
    } else {
      final now = DateTime.now();
      final secs = target.toEnd
          ? ClockLogic.secsToEnd(target.lesson, now)
          : ClockLogic.secsToStart(target.lesson, now);
      label = (target.toEnd ? 'До конца · ' : 'До начала · ') + target.lesson.subject;
      value = ClockLogic.countdown(secs);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.dTextHint, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: valueColor,
              )),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final today = ClockLogic.todayDow(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: List.generate(6, (i) {
          final day = i + 1;
          final active = day == _selDay;
          return Expanded(
            child: InkWell(
              onTap: () => _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      ClockLogic.dayShort(day),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        color: active ? AppTheme.accent : AppTheme.dTextSec,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: day == today ? AppTheme.accent : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayPage(int day) {
    final lessons = _lessonsByDay[day];
    final statuses = _statusesByDay[day];

    if (lessons == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (lessons.isEmpty) {
      return const Center(
        child: Text('Пар нет — отдыхай', style: TextStyle(color: AppTheme.dTextHint, fontSize: 16)),
      );
    }

    final items = <Widget>[];
    for (var i = 0; i < lessons.length; i++) {
      items.add(_LessonCard(
        lesson: lessons[i],
        status: statuses != null && statuses.length > i ? statuses[i] : LessonStatus.future,
        db: _db,
        onHwAdded: () => _loadDay(day),
      ));
      if (i < lessons.length - 1) {
        final br = Bells.breakLabel(lessons[i].num, day);
        if (br.isNotEmpty) {
          items.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Text(br, style: const TextStyle(fontSize: 12, color: AppTheme.dTextHint)),
            ),
          ));
        }
      }
    }
    return ListView(padding: const EdgeInsets.fromLTRB(10, 6, 10, 24), children: items);
  }
}

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final LessonStatus status;
  final DB db;
  final VoidCallback onHwAdded;

  const _LessonCard({
    required this.lesson,
    required this.status,
    required this.db,
    required this.onHwAdded,
  });

  @override
  Widget build(BuildContext context) {
    final isPast = status == LessonStatus.past;

    Color bg = AppTheme.dCard;
    if (status == LessonStatus.now) bg = AppTheme.dNowBg;
    if (status == LessonStatus.next) bg = AppTheme.dNextBg;

    final textColor = isPast ? AppTheme.dTextHint : AppTheme.dText;
    final stripeColor = isPast ? AppTheme.dDivider : AppTheme.accent;

    String? statusText;
    Color statusColor = AppTheme.accent;
    final now = DateTime.now();
    if (status == LessonStatus.now) {
      statusText = '● Идёт — ещё ${ClockLogic.mins(ClockLogic.secsToEnd(lesson, now) ~/ 60)}';
    } else if (status == LessonStatus.next) {
      statusText = '→ Через ${ClockLogic.mins(ClockLogic.minsToStart(lesson, now))}';
    } else if (status == LessonStatus.past) {
      statusText = '✓ Завершена';
      statusColor = AppTheme.dTextHint;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: stripeColor),
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${lesson.num}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isPast ? textColor : AppTheme.accent)),
                  if (lesson.timeStart.isNotEmpty)
                    Text(lesson.timeStart,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9, color: AppTheme.dTextHint)),
                  if (lesson.timeEnd.isNotEmpty)
                    Text(lesson.timeEnd,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9, color: AppTheme.dTextHint)),
                ],
              ),
            ),
            Container(width: 1, color: AppTheme.dDivider),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(lesson.subject,
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                        ),
                        if (lesson.type.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(lesson.type,
                                style: const TextStyle(fontSize: 9, color: AppTheme.dBg)),
                          ),
                      ],
                    ),
                    if (lesson.teacher.isNotEmpty || lesson.room.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            if (lesson.teacher.isNotEmpty)
                              Expanded(
                                child: Text(lesson.teacher,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.dTextSec)),
                              ),
                            if (lesson.room.isNotEmpty)
                              Text(lesson.room,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.dText)),
                          ],
                        ),
                      ),
                    if (statusText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(statusText, style: TextStyle(fontSize: 11, color: statusColor)),
                      ),
                    FutureBuilder<List<Homework>>(
                      future: db.homeworkForSubject(lesson.subject),
                      builder: (context, snap) {
                        final hw = snap.data ?? [];
                        if (hw.isEmpty) return const SizedBox.shrink();
                        var t = '📝 ${hw.first.text}';
                        if (hw.length > 1) t += ' (+${hw.length - 1})';
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(t,
                              style: const TextStyle(fontSize: 11, color: AppTheme.dTextSec)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => _dialogAddHw(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                child: const Text('+ДЗ',
                    style: TextStyle(fontSize: 10, color: AppTheme.dTextSec)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dialogAddHw(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.dCard,
        title: Text(lesson.subject, style: const TextStyle(color: AppTheme.dText)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.dText),
          decoration: const InputDecoration(
            hintText: 'Задание…',
            hintStyle: TextStyle(color: AppTheme.dTextHint),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                final now = DateTime.now();
                final dateStr =
                    '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                await db.saveHomework(lesson.subject, text, dateStr);
                onHwAdded();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
