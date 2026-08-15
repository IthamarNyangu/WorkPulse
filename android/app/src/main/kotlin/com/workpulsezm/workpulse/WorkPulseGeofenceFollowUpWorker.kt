package com.workpulsezm.workpulse

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.time.LocalDate
import java.time.ZoneId

class WorkPulseGeofenceFollowUpWorker(
    context: Context,
    parameters: WorkerParameters,
) : Worker(context, parameters) {
    override fun doWork(): Result {
        val officeId = inputData.getString("officeId") ?: return Result.success()
        val date = inputData.getString("date") ?: return Result.success()
        val userId = inputData.getString("userId") ?: return Result.success()
        val today = LocalDate.now(ZoneId.of("Africa/Lusaka")).toString()
        if (date != today) return Result.success()

        val preferences = applicationContext.getSharedPreferences(
            WorkPulseGeofenceBridge.preferencesName,
            Context.MODE_PRIVATE,
        )
        if (preferences.getString(WorkPulseGeofenceBridge.userIdKey, null) != userId) {
            return Result.success()
        }
        if (preferences.getString(WorkPulseGeofenceBridge.clockedInDateKey, null) == date) {
            return Result.success()
        }
        if (!WorkPulseGeofenceReceiver.isEligibleNow(preferences, date)) {
            return Result.success()
        }

        val officeName = WorkPulseGeofenceBridge.officeName(applicationContext, officeId)
        val eventKey = "geofence_entry_follow_up:$userId:$officeId:$date"
        val title = "Clock In Still Pending"
        val message = "You are still at $officeName without a Clock In record."
        if (WorkPulseGeofenceReceiver.recordEvent(
                applicationContext,
                eventKey,
                title,
                message,
                officeId,
            )
        ) {
            WorkPulseGeofenceReceiver.showNotification(
                applicationContext,
                eventKey,
                title,
                message,
            )
        }
        return Result.success()
    }
}
