package com.ca125.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.widget.RemoteViews

/**
 * Единственный виджет на рабочий стол: большой ОБРАТНЫЙ ОТСЧЁТ сверху —
 * сколько осталось до конца текущей пары, либо до начала следующей —
 * снизу текущая пара, под ней следующая.
 * Обновляется раз в минуту через AlarmManager: посекундный тик виджетам
 * Android не даёт делать штатно (это ограничение платформы, а не наше),
 * поэтому отображаем отсчёт с точностью до минуты, как показания синхронизируются
 * при каждом открытии/обновлении.
 */
class ClockWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) updateOne(context, mgr, id)
        scheduleTick(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TICK || intent.action == "android.appwidget.action.APPWIDGET_UPDATE") {
            refreshAll(context)
            scheduleTick(context)
        }
    }

    override fun onEnabled(context: Context) {
        scheduleTick(context)
    }

    override fun onDisabled(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(tickPendingIntent(context))
    }

    companion object {
        const val ACTION_TICK = "com.ca125.app.WIDGET_TICK"

        fun refreshAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, ClockWidgetProvider::class.java))
            for (id in ids) updateOne(context, mgr, id)
        }

        private fun tickPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, ClockWidgetProvider::class.java).apply { action = ACTION_TICK }
            return PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        /** Планирует обновление виджета раз в минуту, чтобы отсчёт оставался точным. */
        fun scheduleTick(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = tickPendingIntent(context)
            am.setInexactRepeating(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + 60_000L,
                60_000L,
                pi
            )
        }

        private fun updateOne(context: Context, mgr: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_clock)

            val lessons = WidgetData.lessonsForToday(context)
            val current = WidgetData.current(lessons)
            val next = WidgetData.next(lessons, current)

            // ── Большой обратный отсчёт ──────────────────────────
            when {
                current != null -> {
                    views.setTextViewText(R.id.widgetCountdownLabel, "До конца пары")
                    views.setTextViewText(
                        R.id.widgetCountdown,
                        WidgetData.countdown(WidgetData.secsToEnd(current))
                    )
                }
                next != null -> {
                    views.setTextViewText(R.id.widgetCountdownLabel, "До начала пары")
                    views.setTextViewText(
                        R.id.widgetCountdown,
                        WidgetData.countdown(WidgetData.secsToStart(next))
                    )
                }
                else -> {
                    views.setTextViewText(R.id.widgetCountdownLabel, "")
                    views.setTextViewText(R.id.widgetCountdown, "--:--")
                }
            }

            // ── Текущая пара ──────────────────────────────────────
            if (current != null) {
                views.setViewVisibility(R.id.widgetCurrentRow, android.view.View.VISIBLE)
                views.setTextViewText(R.id.widgetCurrentLabel, "Сейчас")
                views.setTextViewText(
                    R.id.widgetCurrentSubject,
                    current.subject + if (current.room.isNotEmpty()) "  ·  ауд. ${current.room}" else ""
                )
                views.setTextViewText(R.id.widgetCurrentTime, "${current.timeStart}–${current.timeEnd}")
            } else {
                views.setViewVisibility(R.id.widgetCurrentRow, android.view.View.GONE)
            }

            // ── Следующая пара ────────────────────────────────────
            if (next != null) {
                views.setViewVisibility(R.id.widgetNextRow, android.view.View.VISIBLE)
                views.setTextViewText(R.id.widgetNextLabel, "Далее")
                views.setTextViewText(
                    R.id.widgetNextSubject,
                    next.subject + if (next.room.isNotEmpty()) "  ·  ауд. ${next.room}" else ""
                )
                views.setTextViewText(R.id.widgetNextTime, "${next.timeStart}–${next.timeEnd}")
            } else {
                views.setViewVisibility(R.id.widgetNextRow, android.view.View.GONE)
            }

            if (current == null && next == null) {
                views.setViewVisibility(R.id.widgetEmptyLabel, android.view.View.VISIBLE)
                views.setTextViewText(R.id.widgetEmptyLabel, "Пар сегодня нет")
            } else {
                views.setViewVisibility(R.id.widgetEmptyLabel, android.view.View.GONE)
            }

            // Тап по виджету открывает приложение
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pi = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widgetRoot, pi)

            mgr.updateAppWidget(id, views)
        }
    }
}
