import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/lesson.dart';
import 'config.dart';
import 'bells.dart';

/// Распознавание расписания из фото через OCR.space + разбор текста.
/// Портировано из Parser.java.
class ParserService {
  static const List<String> _daysRu = [
    'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'
  ];
  static const List<int> _daysNum = [1, 2, 3, 4, 5, 6, 7];

  static final RegExp _pType = RegExp(
    r'\b(лек(?:ция)?|лаб(?:ораторная)?|сем(?:инар)?|практ(?:ика)?|пр|другое)\b',
    caseSensitive: false,
  );

  static final RegExp _pGroup = RegExp(
    r'\b(вся\s+группа|подгруппа\s*\d*)\b',
    caseSensitive: false,
  );

  static final RegExp _pTeacher = RegExp(
    r'^([А-ЯЁ][а-яё]+(?:[-][А-ЯЁ][а-яё]+)?)\s+([А-ЯЁ])\s*[.]?\s*([А-ЯЁ])?\s*[.]?',
  );

  static final RegExp _pTeacherAnywhere = RegExp(
    r'([А-ЯЁ][а-яё]+(?:[-][А-ЯЁ][а-яё]+)?)\s+([А-ЯЁ])\s*[.]?\s*([А-ЯЁ])?\s*[.]?(?=\s|$)',
  );

  /// Распознаёт расписание из байтов фотографии (jpg/png).
  static Future<List<Lesson>> run(Uint8List img) async {
    final text = await _ocr(img);
    final lessons = _parse(text);
    for (final l in lessons) {
      await Bells.applyTo(l);
    }
    return lessons;
  }

  // ══ OCR.space ════════════════════════════════════════

  static String _detectMime(Uint8List img) {
    if (img.length >= 3 && img[0] == 0xFF && img[1] == 0xD8) return 'image/jpeg';
    if (img.length >= 8 && img[0] == 0x89 && img[1] == 0x50 && img[2] == 0x4E && img[3] == 0x47) {
      return 'image/png';
    }
    return 'image/jpeg';
  }

  static Future<String> _ocr(Uint8List img) async {
    final mime = _detectMime(img);
    final b64 = base64Encode(img);

    final uri = Uri.parse('https://api.ocr.space/parse/image');
    final request = http.MultipartRequest('POST', uri);
    request.fields['apikey'] = Config.ocrKey;
    request.fields['language'] = 'rus';
    request.fields['isTable'] = 'true';
    request.fields['scale'] = 'true';
    request.fields['OCREngine'] = '2';
    request.fields['base64Image'] = 'data:$mime;base64,$b64';

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('OCR HTTP ${resp.statusCode}: ${_trim(resp.body, 200)}');
    }

    final r = jsonDecode(resp.body) as Map<String, dynamic>;
    if (r['IsErroredOnProcessing'] == true) {
      throw Exception('OCR ошибка: ${r['ErrorMessage']}');
    }
    final results = r['ParsedResults'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw Exception('OCR: пустой результат');
    }
    final out = StringBuffer();
    for (final res in results) {
      out.write((res as Map<String, dynamic>)['ParsedText'] ?? '');
    }
    return out.toString();
  }

  static String _trim(String s, int max) {
    s = s.trim();
    return s.length > max ? '${s.substring(0, max)}...' : s;
  }

  // ══ Парсинг текста ═══════════════════════════════════

  static List<Lesson> _parse(String raw) {
    final list = <Lesson>[];
    var day = 0;
    var lastNum = 0;
    final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      final d = _detectDay(line);
      if (d > 0) {
        day = d;
        lastNum = 0;
        continue;
      }
      if (day > 0) {
        final l = _parseLine(line, day, lastNum);
        if (l != null) {
          list.add(l);
          lastNum = l.num;
        }
      }
    }
    return list;
  }

  static int _detectDay(String line) {
    final s = line.toLowerCase().replaceAll(RegExp(r'[^а-яё ]'), '').trim();
    for (var i = 0; i < _daysRu.length; i++) {
      if (s == _daysRu[i] || s.startsWith(_daysRu[i])) return _daysNum[i];
    }
    return 0;
  }

  static Lesson? _parseLine(String raw, int day, int lastNum) {
    final line = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (line.isEmpty) return null;

    int num;
    String rest;

    final sp = line.indexOf(' ');
    final firstTok = sp < 0 ? line : line.substring(0, sp);

    if (RegExp(r'^\d+$').hasMatch(firstTok)) {
      num = int.parse(firstTok);
      rest = sp < 0 ? '' : line.substring(sp).trim();
    } else if (firstTok.length <= 2 && sp > 0) {
      num = lastNum + 1;
      rest = line.substring(sp).trim();
    } else {
      num = lastNum + 1;
      rest = line;
    }

    if (num <= 0 || num > 12) return null;
    if (rest.isEmpty) return null;

    final mt = _pType.firstMatch(rest);
    String? subj;
    String type = '';
    String after;

    if (mt != null) {
      final beforeType = rest.substring(0, mt.start).trim();
      type = _normType(mt.group(1));
      after = rest.substring(mt.end).trim();

      final mg = _pGroup.firstMatch(beforeType);
      subj = mg != null ? _clean(beforeType.substring(0, mg.start)) : _clean(beforeType);

      final mg2 = _pGroup.firstMatch(after);
      if (mg2 != null && mg2.start < 30) after = after.substring(mg2.end).trim();
    } else {
      final mg = _pGroup.firstMatch(rest);
      if (mg != null) {
        subj = _clean(rest.substring(0, mg.start));
        after = rest.substring(mg.end).trim();
      } else {
        subj = null;
        after = rest;
      }
    }

    if (subj == null) {
      final mf = _findTeacherAnywhere(rest);
      String s;
      String a;
      if (mf != null) {
        s = _clean(rest.substring(0, mf.start));
        a = rest.substring(mf.end).trim();
      } else {
        s = _clean(rest);
        a = '';
      }
      if (s.isEmpty) return null;
      return _finishLesson(day, num, s, a, type);
    }

    if (subj.isEmpty) {
      if (after.trim().isEmpty) return null;
      subj = '⚠ Не распознано (пара $num)';
    }

    return _finishLesson(day, num, subj, after, type);
  }

  static Lesson _finishLesson(int day, int num, String subj, String after, String type) {
    String teacher = '';
    String room = '';

    final mte = _pTeacher.firstMatch(after);
    if (mte != null) {
      final t = StringBuffer(mte.group(1) ?? '')
        ..write(' ')
        ..write(mte.group(2) ?? '');
      if (mte.group(3) != null) {
        t.write(' ');
        t.write(mte.group(3));
      }
      teacher = t.toString();
      room = after.substring(mte.end).trim();
    } else {
      room = after.trim();
    }
    room = room
        .replaceAll(RegExp(r'^[.,;:\-\s]+'), '')
        .replaceAll(RegExp(r'[|\[\]{}]'), '')
        .trim();

    return Lesson(day: day, num: num, subject: subj, teacher: teacher, room: room, type: type);
  }

  static RegExpMatch? _findTeacherAnywhere(String s) {
    RegExpMatch? last;
    for (final m in _pTeacherAnywhere.allMatches(s)) {
      last = m;
    }
    return last;
  }

  static String _clean(String s) {
    s = s.replaceAll(RegExp('^[-–—•\\s"\']+'), '');
    s = s.replaceAll(RegExp(r'вся\s+группа', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'подгруппа\s*\d*', caseSensitive: false), '');
    s = s.replaceAll(
        RegExp(r'\b(другое|лек(ция)?|лаб(ораторная)?|сем(инар)?|практ(ика)?|пр)\b',
            caseSensitive: false),
        '');
    s = s.replaceAll(RegExp(r'[|\[\]{}]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.replaceAll(RegExp(r'[,;|]+$'), '').trim();
  }

  static String _normType(String? r) {
    if (r == null) return '';
    final l = r.toLowerCase().trim();
    if (l.startsWith('лек')) return 'Лек';
    if (l.startsWith('лаб')) return 'Лаб';
    if (l.startsWith('пр') || l.startsWith('практ')) return 'Пр';
    if (l.startsWith('сем')) return 'Сем';
    return '';
  }
}
