package com.workpulsezm.workpulse

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.util.concurrent.TimeUnit

class WorkPulseGeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return
        event.triggeringGeofences.orEmpty().forEach { geofence ->
            when (event.geofenceTransition) {
                Geofence.GEOFENCE_TRANSITION_DWELL -> handleDwell(context, geofence.requestId)
                Geofence.GEOFENCE_TRANSITION_EXIT -> cancelFollowUp(context, geofence.requestId)
            }
        }
    }

    private fun handleDwell(context: Context, officeId: String) {
        val date = LocalDate.now(ZoneId.of("Africa/Lusaka")).toString()
        val preferences = context.getSharedPreferences(
            WorkPulseGeofenceBridge.preferencesName,
            Context.MODE_PRIVATE,
        )
        if (!preferences.getBoolean(WorkPulseGeofenceBridge.enabledKey, false)) return
        if (!isEligibleNow(preferences, date)) return
        if (preferences.getString(WorkPulseGeofenceBridge.clockedInDateKey, null) == date) return
        val userId = preferences.getString(WorkPulseGeofenceBridge.userIdKey, null) ?: return

        val officeName = WorkPulseGeofenceBridge.officeName(context, officeId)
        val eventKey = "geofence_entry:$userId:$officeId:$date"
        val title = "Clock In Reminder"
        val message = "You have arrived at $officeName. Remember to clock in."
        if (!recordEvent(context, eventKey, title, message, officeId)) return
        showNotification(context, eventKey, title, message)

        val followUp = OneTimeWorkRequestBuilder<WorkPulseGeofenceFollowUpWorker>()
            .setInitialDelay(30, TimeUnit.MINUTES)
            .setInputData(
                Data.Builder()
                    .putString("officeId", officeId)
                    .putString("date", date)
                    .putString("userId", userId)
                    .build(),
            )
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            followUpWorkName(userId, officeId, date),
            ExistingWorkPolicy.KEEP,
            followUp,
        )
    }

    private fun cancelFollowUp(context: Context, officeId: String) {
        val preferences = context.getSharedPreferences(
            WorkPulseGeofenceBridge.preferencesName,
            Context.MODE_PRIVATE,
        )
        val userId = preferences.getString(WorkPulseGeofenceBridge.userIdKey, null) ?: return
        val date = LocalDate.now(ZoneId.of("Africa/Lusaka")).toString()
        WorkManager.getInstance(context).cancelUniqueWork(followUpWorkName(userId, officeId, date))
    }

    companion object {
        private const val arrivalLeadMinutes = 60

        internal fun followUpWorkName(userId: String, officeId: String, date: String): String =
            "workpulse-geofence-follow-up-$userId-$officeId-$date"

        internal fun isEligibleNow(
            preferences: android.content.SharedPreferences,
            date: String,
        ): Boolean {
            val windows = JSONArray(
                preferences.getString(WorkPulseGeofenceBridge.eligibleWindowsKey, "[]") ?: "[]",
            )
            val now = LocalTime.now(ZoneId.of("Africa/Lusaka"))
            val currentMinute = now.hour * 60 + now.minute
            for (index in 0 until windows.length()) {
                val window = windows.optJSONObject(index) ?: continue
                if (window.optString("date") != date) continue
                val startMinute = window.optInt("startMinute", 0)
                val endMinute = window.optInt("endMinute", 0)
                return currentMinute >= (startMinute - arrivalLeadMinutes).coerceAtLeast(0) &&
                    currentMinute <= endMinute
            }
            return false
        }

        internal fun recordEvent(
            context: Context,
            eventKey: String,
            title: String,
            message: String,
            officeId: String,
        ): Boolean {
            val preferences = context.getSharedPreferences(
                WorkPulseGeofenceBridge.preferencesName,
                Context.MODE_PRIVATE,
            )
            if (preferences.getBoolean("delivered:$eventKey", false)) return false
            val events = JSONArray(
                preferences.getString(WorkPulseGeofenceBridge.pendingEventsKey, "[]") ?: "[]",
            )
            events.put(
                JSONObject()
                    .put("eventKey", eventKey)
                    .put("title", title)
                    .put("message", message)
                    .put("occurredAt", Instant.now().toString())
                    .put("officeLocationId", officeId),
            )
            preferences.edit()
                .putBoolean("delivered:$eventKey", true)
                .putString(WorkPulseGeofenceBridge.pendingEventsKey, events.toString())
                .apply()
            return true
        }

        internal fun showNotification(
            context: Context,
            eventKey: String,
            title: String,
            message: String,
        ) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        "workpulse_reminders",
                        "WorkPulse reminders",
                        NotificationManager.IMPORTANCE_HIGH,
                    ).apply { description = "Attendance and leave reminders" },
                )
            }
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                eventKey.hashCode(),
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val notification = NotificationCompat.Builder(context, "workpulse_reminders")
                .setSmallIcon(com.workpulsezm.workpulse.R.drawable.ic_stat_workpulse)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()
            manager.notify(eventKey.hashCode() and 0x7fffffff, notification)
        }
    }
}
