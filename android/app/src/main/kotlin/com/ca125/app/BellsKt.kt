package com.ca125.app

import android.content.Context

/** Расписание звонков — используется виджетом для расчёта времени пары,
 *  если оно не сохранено явно в БД (совпадает по данным с lib/logic/bells.dart).
 *  Пользовательские правки, сделанные в редакторе звонков внутри приложения,
 *  хранятся плагином shared_preferences в стандартном файле настроек Flutter —
 *  читаем их напрямую, чтобы виджет не расходился с приложением. */
object BellsKt {
    // [день-режим][пара][0=начало,1=конец]
    private val DEF = arrayOf(
        // Понедельник
        arrayOf(
            arrayOf("08:00", "08:55"), arrayOf("09:00", "10:30"), arrayOf("10:40", "12:10"),
            arrayOf("12:50", "14:20"), arrayOf("14:30", "16:00"), arrayOf("16:05", "17:35")
        ),
        // Вторник–Пятница
        arrayOf(
            arrayOf("08:15", "09:45"), arrayOf("09:55", "11:25"), arrayOf("12:05", "13:35"),
            arrayOf("13:45", "15:15"), arrayOf("15:25", "16:55"), arrayOf("17:00", "18:30")
        ),
        // Суббота
        arrayOf(
            arrayOf("08:15", "09:15"), arrayOf("09:25", "10:25"), arrayOf("10:35", "11:35"),
            arrayOf("11:45", "12:45"), arrayOf("12:55", "13:55"), arrayOf("14:05", "15:05")
        )
    )

    fun modeFor(dayOfWeek: Int): Int = when (dayOfWeek) {
        1 -> 0 // Пн
        6 -> 2 // Сб
        else -> 1 // Вт-Пт
    }

    fun defStart(mode: Int, idx: Int): String = DEF[mode][idx][0]
    fun defEnd(mode: Int, idx: Int): String = DEF[mode][idx][1]

    // Плагин shared_preferences хранит значения с этим префиксом ключей
    // в файле "FlutterSharedPreferences".
    private const val PREFS_FILE = "FlutterSharedPreferences"
    private const val KEY_PREFIX = "flutter."

    private fun keyName(mode: Int, idx: Int, isStart: Boolean): String =
        "${KEY_PREFIX}bells_m${mode}_$idx${if (isStart) "s" else "e"}"

    /** Начало пары с учётом пользовательской правки (если есть), иначе дефолт. */
    fun start(ctx: Context, mode: Int, idx: Int): String {
        val prefs = ctx.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        return prefs.getString(keyName(mode, idx, true), null) ?: defStart(mode, idx)
    }

    /** Конец пары с учётом пользовательской правки (если есть), иначе дефолт. */
    fun end(ctx: Context, mode: Int, idx: Int): String {
        val prefs = ctx.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        return prefs.getString(keyName(mode, idx, false), null) ?: defEnd(mode, idx)
    }
}
