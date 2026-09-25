import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/lesson.dart';
import '../models/homework.dart';
import '../models/exam.dart';

class DB {
  static final DB _instance = DB._internal();
  factory DB() => _instance;
  DB._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'ca125.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE lessons(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            day INTEGER, num INTEGER, subject TEXT,
            teacher TEXT, room TEXT,
            t_start TEXT, t_end TEXT, type TEXT)
        ''');
        await db.execute('''
          CREATE TABLE homework(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subject TEXT, text TEXT, due_date TEXT, done INTEGER DEFAULT 0)
        ''');
        await db.execute('''
          CREATE TABLE exams(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subject TEXT, type TEXT, date TEXT,
            time TEXT, room TEXT, note TEXT)
        ''');
      },
    );
  }

  Future<void> clearLessons() async {
    final db = await database;
    await db.delete('lessons');
  }

  Future<int> saveLesson(Lesson l) async {
    final db = await database;
    return db.insert('lessons', l.toMap()..remove('id'));
  }

  Future<void> saveLessons(List<Lesson> lessons) async {
    final db = await database;
    final batch = db.batch();
    for (final l in lessons) {
      batch.insert('lessons', l.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<List<Lesson>> lessonsForDay(int day) async {
    final db = await database;
    final rows = await db.query('lessons', where: 'day=?', whereArgs: [day], orderBy: 'num ASC');
    return rows.map((r) => Lesson.fromMap(r)).toList();
  }

  Future<List<Lesson>> allLessons() async {
    final db = await database;
    final rows = await db.query('lessons', orderBy: 'day ASC, num ASC');
    return rows.map((r) => Lesson.fromMap(r)).toList();
  }

  Future<bool> hasLessons() async {
    final db = await database;
    final res = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM lessons'));
    return (res ?? 0) > 0;
  }

  Future<List<Lesson>> searchLessons(String q) async {
    final db = await database;
    final like = '%$q%';
    final rows = await db.query(
      'lessons',
      where: 'subject LIKE ? OR teacher LIKE ? OR room LIKE ?',
      whereArgs: [like, like, like],
      orderBy: 'day ASC, num ASC',
    );
    return rows.map((r) => Lesson.fromMap(r)).toList();
  }

  // ══ HOMEWORK ═════════════════════════════════════════

  Future<int> saveHomework(String subject, String text, String dueDate) async {
    final db = await database;
    return db.insert('homework', {
      'subject': subject,
      'text': text,
      'due_date': dueDate,
      'done': 0,
    });
  }

  Future<void> toggleHomework(int id, bool done) async {
    final db = await database;
    await db.update('homework', {'done': done ? 1 : 0}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteHomework(int id) async {
    final db = await database;
    await db.delete('homework', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Homework>> allHomework() async {
    final db = await database;
    final rows = await db.query('homework', orderBy: 'done ASC, due_date ASC');
    return rows.map((r) => Homework.fromMap(r)).toList();
  }

  Future<List<Homework>> homeworkForSubject(String subject) async {
    final db = await database;
    final rows = await db.query(
      'homework',
      where: 'subject=? AND done=0',
      whereArgs: [subject],
      orderBy: 'due_date ASC',
    );
    return rows.map((r) => Homework.fromMap(r)).toList();
  }

  // ══ EXAMS ════════════════════════════════════════════

  Future<int> saveExam(Exam e) async {
    final db = await database;
    return db.insert('exams', e.toMap()..remove('id'));
  }

  Future<void> deleteExam(int id) async {
    final db = await database;
    await db.delete('exams', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Exam>> allExams() async {
    final db = await database;
    final rows = await db.query('exams', orderBy: 'date ASC, time ASC');
    return rows.map((r) => Exam.fromMap(r)).toList();
  }
}
