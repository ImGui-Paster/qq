package com.ca125.app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

data class WidgetLesson(
    val num: Int,
    val subject: String,
    val room: String,
    val timeStart: String,
    val timeEnd: String
)

/** Читает расписание напрямую из БД, которую ведёт Flutter-приложение
 *  (sqflite создаёт её по стандартному пути getDatabasesPath()/ca125.db —
 *  тому же, что использует Android SQLiteOpenHelper). */
object WidgetData {

    private fun dbPath(ctx: Context): String {
        // На Android sqflite хранит базы в том же каталоге, что и
        // context.getDatabasePath(name) — стандартный путь приложения.
        return ctx.getDatabasePath("ca125.db").absolutePath
    }

    fun todayDow(): Int {
        val c = Calendar.getInstance()
        val d = c.get(Calendar.DAY_OF_WEEK)
        return if (d == Calendar.SUNDAY) 0 else d - 1
    }

    fun nowMin(): Int {
        val c = Calendar.getInstance()
        return c.get(Calendar.HOUR_OF_DAY) * 60 + c.get(Calendar.MINUTE)
    }

    fun toMin(t: String?): Int {
        if (t.isNullOrEmpty()) return -1
        return try {
            val p = t.replace(".", ":").split(":")
            p[0].trim().toInt() * 60 + p[1].trim().toInt()
        } catch (e: Exception) {
            -1
        }
    }

    /** Пары сегодняшнего дня, отсортированные по номеру. Время подставляется
     *  по умолчанию (Bells), если явно не задано в БД. */
    fun lessonsForToday(ctx: Context): List<WidgetLesson> {
        val dow = todayDow()
        if (dow == 0) return emptyList() // воскресенье — пар нет

        val path = dbPath(ctx)
        if (!File(path).exists()) return emptyList()

        val result = mutableListOf<WidgetLesson>()
        try {
            val db = SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY)
            val cursor = db.rawQuery(
                "SELECT num, subject, room, t_start, t_end FROM lessons WHERE day=? ORDER BY num ASC",
                arrayOf(dow.toString())
            )
            val mode = BellsKt.modeFor(dow)
            while (cursor.moveToNext()) {
                val num = cursor.getInt(0)
                val subject = cursor.getString(1) ?: ""
                val room = cursor.getString(2) ?: ""
                var start = cursor.getString(3) ?: ""
                var end = cursor.getString(4) ?: ""
                val idx = num - 1
                if (start.isEmpty() && idx in 0..5) start = BellsKt.start(ctx, mode, idx)
                if (end.isEmpty() && idx in 0..5) end = BellsKt.end(ctx, mode, idx)
                result.add(WidgetLesson(num, subject, room, start, end))
            }
            cursor.close()
            db.close()
        } catch (e: Exception) {
            // БД ещё не создана / расписание не загружено — просто пусто
        }
        return result
    }

    /** Текущая пара (идёт сейчас), либо null. */
    fun current(lessons: List<WidgetLesson>): WidgetLesson? {
        val now = nowMin()
        return lessons.firstOrNull { l ->
            val s = toMin(l.timeStart); val e = toMin(l.timeEnd)
            s >= 0 && e >= 0 && now in s until e
        }
    }

    /** Следующая пара после текущего момента (не текущая), либо null. */
    fun next(lessons: List<WidgetLesson>, current: WidgetLesson?): WidgetLesson? {
        val now = nowMin()
        return lessons.filter { it != current }
            .filter { toMin(it.timeStart) > now }
            .minByOrNull { toMin(it.timeStart) }
    }

    fun nowSec(): Int {
        val c = Calendar.getInstance()
        return c.get(Calendar.HOUR_OF_DAY) * 3600 + c.get(Calendar.MINUTE) * 60 + c.get(Calendar.SECOND)
    }

    fun toSec(t: String?): Int {
        val m = toMin(t)
        return if (m < 0) -1 else m * 60
    }

    /** Секунд до конца пары (для текущей). */
    fun secsToEnd(l: WidgetLesson): Int = toSec(l.timeEnd) - nowSec()

    /** Секунд до начала пары (для следующей). */
    fun secsToStart(l: WidgetLesson): Int = toSec(l.timeStart) - nowSec()

    /** Форматирует обратный отсчёт как MM:SS или HH:MM:SS. */
    fun countdown(totalSecs: Int): String {
        val secs = if (totalSecs < 0) 0 else totalSecs
        val h = secs / 3600
        val m = (secs % 3600) / 60
        val s = secs % 60
        return if (h > 0) {
            String.format(Locale.getDefault(), "%02d:%02d:%02d", h, m, s)
        } else {
            String.format(Locale.getDefault(), "%02d:%02d", m, s)
        }
    }

    fun timeNow(): String = SimpleDateFormat("HH:mm", Locale.getDefault()).format(java.util.Date())
}
