import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static Future<int> getLastSync() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt('last_sync') ?? 0;
  }

  static Future<void> setLastSync(int v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('last_sync', v);
  }

  static Future<int> getNotifyMins() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt('notify_mins') ?? 15;
  }

  static Future<void> setNotifyMins(int v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('notify_mins', v);
  }
}
