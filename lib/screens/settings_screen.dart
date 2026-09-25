import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../logic/app_theme.dart';
import '../logic/db.dart';
import '../logic/parser.dart';
import '../logic/prefs.dart';
import 'bell_editor_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DB _db = DB();
  bool _importing = false;
  String? _status;
  int _notifyMins = 15;

  @override
  void initState() {
    super.initState();
    Prefs.getNotifyMins().then((v) => setState(() => _notifyMins = v));
  }

  Future<void> _pickAndImport() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (xfile == null) return;

    setState(() {
      _importing = true;
      _status = 'Распознаём…';
    });

    try {
      final bytes = await File(xfile.path).readAsBytes();
      final lessons = await ParserService.run(bytes);
      if (lessons.isEmpty) {
        setState(() {
          _importing = false;
          _status = 'Расписание не распознано. Попробуйте фото почётче.';
        });
        return;
      }
      await _db.clearLessons();
      await _db.saveLessons(lessons);
      await Prefs.setLastSync(DateTime.now().millisecondsSinceEpoch);

      setState(() {
        _importing = false;
        _status = 'Загружено пар: ${lessons.length}';
      });
    } catch (e) {
      setState(() {
        _importing = false;
        _status = 'Ошибка: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dBg,
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            title: 'Расписание',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Загрузите фото расписания — оно будет распознано автоматически.',
                    style: TextStyle(color: AppTheme.dTextSec)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _importing ? null : _pickAndImport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.dBg,
                  ),
                  icon: const Icon(Icons.photo_library),
                  label: Text(_importing ? 'Распознаём…' : 'Загрузить фото'),
                ),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_status!, style: const TextStyle(color: AppTheme.dTextSec)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _section(
            title: 'Уведомления',
            child: Row(
              children: [
                const Text('За сколько минут напоминать:',
                    style: TextStyle(color: AppTheme.dTextSec)),
                const Spacer(),
                DropdownButton<int>(
                  value: _notifyMins,
                  dropdownColor: AppTheme.dCard,
                  style: const TextStyle(color: AppTheme.dText),
                  items: const [5, 10, 15, 20, 30]
                      .map((m) => DropdownMenuItem(value: m, child: Text('$m мин')))
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    await Prefs.setNotifyMins(v);
                    setState(() => _notifyMins = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _section(
            title: 'Расписание звонков',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Время начала и конца пар по умолчанию (Пн / Вт–Пт / Сб).',
                    style: TextStyle(color: AppTheme.dTextSec)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BellEditorScreen())),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: AppTheme.accent),
                  ),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Изменить расписание звонков'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.dText, fontSize: 15)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
