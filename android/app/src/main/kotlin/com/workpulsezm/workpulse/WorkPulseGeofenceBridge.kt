package com.workpulsezm.workpulse

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

object WorkPulseGeofenceBridge {
    private const val channelName = "workpulse/geofencing"
    internal const val preferencesName = "workpulse_geofencing"
    internal const val officesKey = "offices"
    internal const val eligibleWindowsKey = "eligible_windows"
    internal const val clockedInDateKey = "clocked_in_date"
    internal const val userIdKey = "user_id"
    internal const val enabledKey = "enabled"
    internal const val pendingEventsKey = "pending_events"
    internal const val dwellMilliseconds = 3 * 60 * 1000
    private const val maxRegisteredOffices = 95

    fun configure(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "permissionState" -> result.success(permissionState(activity))
                "openLocationSettings" -> {
                    activity.startActivity(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:${activity.packageName}"),
                        ),
                    )
                    result.success(null)
                }
                "configure" -> configureGeofences(
                    context = activity,
                    offices = call.argument<List<Map<String, Any?>>>("offices").orEmpty(),
                    eligibleWindows = call.argument<List<Map<String, Any?>>>("eligibleWindows")
                        .orEmpty(),
                    clockedInDate = call.argument<String>("clockedInDate"),
                    userId = call.argument<String>("userId").orEmpty(),
                    enabled = call.argument<Boolean>("enabled") ?: true,
                    result = result,
                )
                "drainEvents" -> result.success(drainEvents(activity))
                "clear" -> {
                    clear(activity)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun permissionState(context: Context): Map<String, Boolean> {
        val foreground = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val background = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        return mapOf("foreground" to foreground, "background" to background)
    }

    private fun configureGeofences(
        context: Context,
        offices: List<Map<String, Any?>>,
        eligibleWindows: List<Map<String, Any?>>,
        clockedInDate: String?,
        userId: String,
        enabled: Boolean,
        result: MethodChannel.Result,
    ) {
        val limitedOffices = offices.take(maxRegisteredOffices)
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        preferences.edit()
            .putBoolean(enabledKey, enabled)
            .putString(officesKey, JSONArray(limitedOffices).toString())
            .putString(eligibleWindowsKey, JSONArray(eligibleWindows).toString())
            .putString(clockedInDateKey, clockedInDate)
            .putString(userIdKey, userId)
            .apply()

        if (!enabled || limitedOffices.isEmpty()) {
            removeGeofences(context)
            result.success(mapOf("registered" to 0, "permissionRequired" to false))
            return
        }

        val permission = permissionState(context)
        if (permission["foreground"] != true || permission["background"] != true) {
            result.success(mapOf("registered" to 0, "permissionRequired" to true))
            return
        }

        register(context, limitedOffices, result)
    }

    @SuppressLint("MissingPermission")
    private fun register(
        context: Context,
        offices: List<Map<String, Any?>>,
        result: MethodChannel.Result? = null,
    ) {
        val geofences = offices.mapNotNull { office ->
            val id = office["id"] as? String ?: return@mapNotNull null
            val latitude = (office["latitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            val longitude = (office["longitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            val radius = (office["radiusMeters"] as? Number)?.toFloat() ?: return@mapNotNull null
            Geofence.Builder()
                .setRequestId(id)
                .setCircularRegion(latitude, longitude, radius)
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(
                    Geofence.GEOFENCE_TRANSITION_DWELL or
                        Geofence.GEOFENCE_TRANSITION_EXIT,
                )
                .setLoiteringDelay(dwellMilliseconds)
                .build()
        }
        if (geofences.isEmpty()) {
            result?.success(mapOf("registered" to 0, "permissionRequired" to false))
            return
        }

        val client = LocationServices.getGeofencingClient(context)
        client.removeGeofences(pendingIntent(context)).addOnCompleteListener {
            val request = GeofencingRequest.Builder()
                .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_DWELL)
                .addGeofences(geofences)
                .build()
            client.addGeofences(request, pendingIntent(context))
                .addOnSuccessListener {
                    result?.success(
                        mapOf("registered" to geofences.size, "permissionRequired" to false),
                    )
                }
                .addOnFailureListener { error ->
                    result?.error("geofence_registration_failed", error.localizedMessage, null)
                }
        }
    }

    fun registerCached(context: Context) {
        val permission = permissionState(context)
        if (permission["foreground"] != true || permission["background"] != true) return
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        if (!preferences.getBoolean(enabledKey, false)) return
        val raw = preferences.getString(officesKey, null) ?: return
        val array = JSONArray(raw)
        val offices = (0 until array.length()).map { index ->
            val item = array.getJSONObject(index)
            mapOf<String, Any?>(
                "id" to item.optString("id"),
                "latitude" to item.optDouble("latitude"),
                "longitude" to item.optDouble("longitude"),
                "radiusMeters" to item.optDouble("radiusMeters"),
            )
        }
        register(context, offices)
    }

    private fun clear(context: Context) {
        removeGeofences(context)
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit().clear().apply()
    }

    private fun removeGeofences(context: Context) {
        val client: GeofencingClient = LocationServices.getGeofencingClient(context)
        client.removeGeofences(pendingIntent(context))
    }

    internal fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, WorkPulseGeofenceReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            8103,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }

    private fun drainEvents(context: Context): List<Map<String, Any?>> {
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val raw = preferences.getString(pendingEventsKey, "[]") ?: "[]"
        preferences.edit().putString(pendingEventsKey, "[]").apply()
        val array = JSONArray(raw)
        return (0 until array.length()).map { index ->
            val event = array.getJSONObject(index)
            mapOf(
                "eventKey" to event.optString("eventKey"),
                "title" to event.optString("title"),
                "message" to event.optString("message"),
                "occurredAt" to event.optString("occurredAt"),
                "officeLocationId" to event.optString("officeLocationId"),
            )
        }
    }

    internal fun officeName(context: Context, officeId: String): String {
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val array = JSONArray(preferences.getString(officesKey, "[]") ?: "[]")
        for (index in 0 until array.length()) {
            val office = array.getJSONObject(index)
            if (office.optString("id") == officeId) {
                return office.optString("officeName", "an approved office")
            }
        }
        return "an approved office"
    }
}
