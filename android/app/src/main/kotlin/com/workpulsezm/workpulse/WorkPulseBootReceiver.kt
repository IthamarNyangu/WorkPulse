package com.workpulsezm.workpulse

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class WorkPulseBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            WorkPulseGeofenceBridge.registerCached(context)
        }
    }
}
