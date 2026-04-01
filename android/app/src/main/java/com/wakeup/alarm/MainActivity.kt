package com.wakeup.alarm

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.wakeup.alarm/ringtone"
    private val ALARM_CHANNEL = "com.wakeup.alarm/alarm_manager"
    private val EVENT_CHANNEL = "com.wakeup.alarm/alarm_events"
    private var mediaPlayer: MediaPlayer? = null
    private var alarmEventSink: EventChannel.EventSink? = null

    companion object {
        // Datos de la alarma pendiente para enviarse a Flutter cuando esté listo
        var pendingAlarmLabel: String? = null
        var pendingAlarmSound: String? = null
        var pendingAlarmGradual: Boolean = false
        var pendingAlarmId: Int = -1
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Leer intent si vino desde AlarmReceiver
        handleAlarmIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAlarmIntent(intent)
    }

    private fun handleAlarmIntent(intent: Intent?) {
        if (intent?.action == "FIRE_ALARM") {
            pendingAlarmLabel = intent.getStringExtra("alarm_label") ?: "WAKE UP"
            pendingAlarmSound = intent.getStringExtra("alarm_sound") ?: ""
            pendingAlarmGradual = intent.getBooleanExtra("alarm_gradual", false)
            pendingAlarmId = intent.getIntExtra("alarm_id", -1)
            // Notificar a Flutter si ya está listo
            alarmEventSink?.success(mapOf(
                "label" to pendingAlarmLabel,
                "sound" to pendingAlarmSound,
                "gradual" to pendingAlarmGradual,
                "id" to pendingAlarmId
            ))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel: envía eventos de alarma a Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    alarmEventSink = sink
                    // Si hay una alarma pendiente cuando Flutter se conecta, enviarla ahora
                    if (pendingAlarmLabel != null) {
                        sink?.success(mapOf(
                            "label" to pendingAlarmLabel,
                            "sound" to pendingAlarmSound,
                            "gradual" to pendingAlarmGradual,
                            "id" to pendingAlarmId
                        ))
                        pendingAlarmLabel = null
                    }
                }
                override fun onCancel(args: Any?) { alarmEventSink = null }
            })

        // MethodChannel: audio/ringtone
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playRingtone" -> {
                        playRingtone(
                            call.argument("uri"),
                            (call.argument<Double>("volume") ?: 1.0).toFloat(),
                            call.argument<Boolean>("loop") ?: true
                        )
                        result.success(null)
                    }
                    "stopRingtone" -> { stopRingtone(); result.success(null) }
                    "setVolume" -> {
                        mediaPlayer?.setVolume(
                            (call.argument<Double>("volume") ?: 1.0).toFloat(),
                            (call.argument<Double>("volume") ?: 1.0).toFloat()
                        )
                        result.success(null)
                    }
                    "getSystemRingtones" -> result.success(getSystemRingtones())
                    else -> result.notImplemented()
                }
            }

        // MethodChannel: gestión de alarmas
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        scheduleAlarm(
                            call.argument<Int>("id") ?: 0,
                            call.argument<Long>("triggerMs") ?: 0L,
                            call.argument<String>("label") ?: "WAKE UP",
                            call.argument<String>("sound") ?: "",
                            call.argument<Boolean>("gradual") ?: false
                        )
                        result.success(null)
                    }
                    "cancelAlarm" -> {
                        cancelAlarm(call.argument<Int>("id") ?: 0)
                        result.success(null)
                    }
                    "stopAlarmService" -> {
                        stopService(Intent(this, AlarmService::class.java))
                        pendingAlarmLabel = null
                        result.success(null)
                    }
                    "requestBatteryOptimization" -> {
                        requestIgnoreBatteryOptimizations(); result.success(null)
                    }
                    "requestExactAlarm" -> {
                        requestExactAlarmPermission(); result.success(null)
                    }
                    "checkPermissions" -> {
                        result.success(mapOf(
                            "notifications" to NotificationManagerCompat.from(this).areNotificationsEnabled(),
                            "exactAlarm" to hasExactAlarmPermission(),
                            "batteryOptimization" to isIgnoringBatteryOptimizations()
                        ))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun scheduleAlarm(id: Int, triggerMs: Long, label: String, sound: String, gradual: Boolean) {
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = "com.wakeup.alarm.FIRE_ALARM"
            putExtra("id", id)
            putExtra("label", label)
            putExtra("sound", sound)
            putExtra("gradual", gradual)
        }
        val pi = PendingIntent.getBroadcast(this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms()) {
                am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerMs, pi), pi)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerMs, pi)
            }
        } catch (e: Exception) {
            am.set(AlarmManager.RTC_WAKEUP, triggerMs, pi)
        }
    }

    private fun cancelAlarm(id: Int) {
        val intent = Intent(this, AlarmReceiver::class.java)
        val pi = PendingIntent.getBroadcast(this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        (getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pi)
    }

    private fun hasExactAlarmPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return (getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms()
        }
        return true
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (!isIgnoringBatteryOptimizations()) {
            startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            })
        }
    }

    private fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !hasExactAlarmPermission()) {
            startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM))
        }
    }

    private fun playRingtone(uriString: String?, volume: Float, loop: Boolean) {
        try {
            stopRingtone()
            val uri = resolveUri(uriString)
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED)
                    .build())
                setDataSource(applicationContext, uri)
                isLooping = loop
                setVolume(volume, volume)
                prepare()
                start()
            }
        } catch (e: Exception) {
            try {
                val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(applicationContext, defaultUri)
                    isLooping = loop; setVolume(volume, volume); prepare(); start()
                }
            } catch (ex: Exception) { ex.printStackTrace() }
        }
    }

    private fun resolveUri(uriString: String?): Uri {
        return when {
            uriString.isNullOrEmpty() || uriString == "beep" || uriString == "default_alarm" ->
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            uriString == "default_ringtone" ->
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            uriString.startsWith("content://") || uriString.startsWith("android.resource://") ->
                Uri.parse(uriString)
            uriString.startsWith("/") -> Uri.parse("file://$uriString")
            else -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        }
    }

    private fun stopRingtone() {
        mediaPlayer?.let {
            try { if (it.isPlaying) it.stop() } catch (_: Exception) {}
            it.release()
        }
        mediaPlayer = null
    }

    private fun getSystemRingtones(): List<Map<String, String>> {
        val ringtones = mutableListOf<Map<String, String>>()
        try {
            val manager = RingtoneManager(this).apply { setType(RingtoneManager.TYPE_ALARM) }
            val cursor = manager.cursor
            while (cursor.moveToNext()) {
                ringtones.add(mapOf(
                    "title" to cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX),
                    "uri" to manager.getRingtoneUri(cursor.position).toString()
                ))
            }
            cursor.close()
        } catch (e: Exception) { e.printStackTrace() }
        return ringtones
    }

    override fun onDestroy() { stopRingtone(); super.onDestroy() }
}
