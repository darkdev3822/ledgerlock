package com.darkdev.ledgerlock

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * Home-screen widget: the next estimated-tax due date and how many days are left (SPEC §3 widgets).
 *
 * Privacy: it shows ONLY the IRS calendar bundled in the app (assets/tax_rules/<year>.json), never anything from the
 * user's encrypted vault, so it is safe on a home screen and lock screen and needs no unlock and no stored copy of
 * any user data. No network: it recomputes from the bundled files once a day.
 */
class DueWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val views = render(context)
        for (id in ids) manager.updateAppWidget(id, views)
        scheduleMidnight(context)
    }

    override fun onDisabled(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(refreshIntent(context))
    }

    companion object {
        /** (quarter, due date as UTC midnight millis) for every bundled year, sorted. */
        fun dueDates(context: Context): List<Pair<String, Long>> {
            val out = mutableListOf<Pair<String, Long>>()
            val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
            val dir = "flutter_assets/assets/tax_rules"
            for (name in context.assets.list(dir).orEmpty()) {
                if (!Regex("""\d{4}\.json""").matches(name)) continue
                try {
                    val json = context.assets.open("$dir/$name").bufferedReader().use { it.readText() }
                    val due = JSONObject(json).optJSONArray("quarterlyDue") ?: continue
                    for (i in 0 until due.length()) {
                        val q = due.getJSONObject(i)
                        val d = fmt.parse(q.getString("due")) ?: continue
                        out.add(q.getString("quarter") to d.time)
                    }
                } catch (_: Exception) {
                    // A broken file just contributes nothing.
                }
            }
            return out.sortedBy { it.second }
        }

        /** Today's local date as UTC midnight millis, so day counts never drift with DST. */
        private fun todayUtc(): Long {
            val local = Calendar.getInstance()
            return Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
                clear()
                set(local.get(Calendar.YEAR), local.get(Calendar.MONTH), local.get(Calendar.DAY_OF_MONTH))
            }.timeInMillis
        }

        fun render(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_due)
            val today = todayUtc()
            val next = dueDates(context).firstOrNull { it.second >= today }
            if (next == null) {
                views.setTextViewText(R.id.widget_main, "No dates yet")
                views.setTextViewText(R.id.widget_sub, "Update LedgerLock for next year")
            } else {
                val days = ((next.second - today) / 86_400_000L).toInt()
                val date = SimpleDateFormat("MMM d", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
                    .format(next.second)
                views.setTextViewText(R.id.widget_main, "${next.first} · $date")
                views.setTextViewText(
                    R.id.widget_sub,
                    when (days) {
                        0 -> "Due today"
                        1 -> "Due tomorrow"
                        else -> "in $days days"
                    },
                )
            }
            val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (open != null) {
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT),
                )
            }
            return views
        }

        private fun refreshIntent(context: Context): PendingIntent {
            val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, DueWidget::class.java))
            val i = Intent(context, DueWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            return PendingIntent.getBroadcast(context, 77, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }

        /** Refresh just after local midnight so "in N days" is right each morning (inexact: no special permission). */
        private fun scheduleMidnight(context: Context) {
            val at = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 5)
                set(Calendar.SECOND, 0)
            }.timeInMillis
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
                .set(AlarmManager.RTC, at, refreshIntent(context))
        }
    }
}
