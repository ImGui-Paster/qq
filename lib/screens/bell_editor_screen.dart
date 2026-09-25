import 'package:flutter/material.dart';
import '../logic/app_theme.dart';
import '../logic/bells.dart';

/// Полноценный редактор расписания звонков: 3 вкладки режимов
/// (Пн / Вт–Пт / Сб), время начала и конца каждой пары через TimePicker,
/// кнопки «По умолчанию» и «Сохранить». Портировано с BellActivity.java.
class BellEditorScreen extends StatefulWidget {
  const BellEditorScreen({super.key});
  @override
  State<BellEditorScreen> createState() => _BellEditorScreenState();
}

class _BellEditorScreenState extends State<BellEditorScreen> {
  // vals[mode][lessonIdx][0=start,1=end]
  final List<List<List<String>>> _vals =
      List.generate(3, (_) => List.generate(6, (_) => ['--:--', '--:--']));
  int _curMode = 1;
  bool _loading = true;

  static const _modeLabels = ['Пн', 'Вт–Пт', 'Сб'];
  static const _modeTitles = ['Понедельник', 'Вторник – Пятница', 'Суббота'];

  @override
  void initState() {
    super.initState();
    _loadVals();
  }

  Future<void> _loadVals() async {
    for (var m = 0; m < 3; m++) {
      for (var i = 0; i < 6; i++) {
        _vals[m][i][0] = await Bells.start(m, i);
        _vals[m][i][1] = await Bells.end(m, i);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickTime(int mode, int idx, bool isStart) async {
    final cur = _vals[mode][idx][isStart ? 0 : 1];
    var h = 8, m = 0;
    try {
      final p = cur.split(':');
      h = int.parse(p[0].trim());
      m = int.parse(p[1].trim());
    } catch (_) {}

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accent,
            surface: AppTheme.dCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => _vals[mode][idx][isStart ? 0 : 1] = formatted);
  }

  Future<void> _reset() async {
    await Bells.reset();
    await _loadVals();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Сброшено')));
    }
  }

  Future<void> _save() async {
    for (var m = 0; m < 3; m++) {
      for (var i = 0; i < 6; i++) {
        await Bells.set(m, i, _vals[m][i][0], _vals[m][i][1]);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Расписание звонков сохранено')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dBg,
      appBar: AppBar(title: const Text('Расписание звонков')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildModeTabs(),
                Expanded(child: _buildList()),
                _buildButtons(),
              ],
            ),
    );
  }

  Widget _buildModeTabs() {
    return Container(
      color: AppTheme.dHeader,
      child: Row(
        children: List.generate(3, (i) {
          final active = i == _curMode;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _curMode = i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _modeLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: active ? AppTheme.accent : AppTheme.dTextSec,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Text(_modeTitles[_curMode],
              style: const TextStyle(color: AppTheme.accent, fontSize: 13)),
        ),
        for (var i = 0; i < 6; i++) _buildRow(i),
      ],
    );
  }

  Widget _buildRow(int idx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            child: Text('${idx + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accent)),
          ),
          const Text(' пара  ', style: TextStyle(fontSize: 11, color: AppTheme.dTextHint)),
          Expanded(child: _timeBtn(_curMode, idx, true)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('–', style: TextStyle(color: AppTheme.dTextHint)),
          ),
          Expanded(child: _timeBtn(_curMode, idx, false)),
        ],
      ),
    );
  }

  Widget _timeBtn(int mode, int idx, bool isStart) {
    final time = _vals[mode][idx][isStart ? 0 : 1];
    return InkWell(
      onTap: () => _pickTime(mode, idx, isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.dSurface,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(time,
            style: const TextStyle(
                fontSize: 16, fontFamily: 'monospace', color: AppTheme.accent)),
      ),
    );
  }

  Widget _buildButtons() {
    return Container(
      color: AppTheme.dHeader,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _reset,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.dTextSec,
                side: const BorderSide(color: AppTheme.dDivider),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('По умолчанию'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.dBg,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}
