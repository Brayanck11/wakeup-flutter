package com.wakeup.alarm

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.*
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class AlarmService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val CHANNEL_ID = "wakeup_alarm_channel"
    private val NOTIF_ID = 1001

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val alarmLabel = intent?.getStringExtra("label") ?: "WAKE UP"
        val soundUri = intent?.getStringExtra("sound") ?: ""
        val gradual = intent?.getBooleanExtra("gradual", false) ?: false

        // Iniciar como foreground service — esto es lo que permite sonar con pantalla apagada
        val notification = buildNotification(alarmLabel)
        startForeground(NOTIF_ID, notification)

        // Reproducir sonido
        playAlarmSound(soundUri, gradual)

        // Vibrar
        vibrate()

        return START_STICKY
    }

    private fun playAlarmSound(soundUri: String, gradual: Boolean) {
        try {
            stopSound()
            val uri: Uri = when {
                soundUri.isEmpty() || soundUri == "beep" || soundUri == "default_alarm" ->
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                soundUri == "default_ringtone" ->
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                soundUri.startsWith("content://") ->
                    Uri.parse(soundUri)
                soundUri.startsWith("/") ->
                    Uri.parse("file://$soundUri")
                else ->
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            }

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED)
                        .build()
                )
                setDataSource(applicationContext, uri)
                isLooping = true
                val startVol = if (gradual) 0.05f else 1.0f
                setVolume(startVol, startVol)
                prepare()
                start()
            }

            // Volumen gradual
            if (gradual) {
                val handler = Handler(Looper.getMainLooper())
                var vol = 0.05f
                val runnable = object : Runnable {
                    override fun run() {
                        vol = (vol + 0.1f).coerceAtMost(1.0f)
                        mediaPlayer?.setVolume(vol, vol)
                        if (vol < 1.0f) handler.postDelayed(this, 2000)
                    }
                }
                handler.postDelayed(runnable, 2000)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun vibrate() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            val pattern = longArrayOf(0, 300, 200, 300, 200, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, 0)
            }
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "WakeUp::AlarmWakeLock"
            ).apply { acquire(10 * 60 * 1000L) }
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun buildNotification(label: String): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("⏰ $label")
            .setContentText("Toca para resolver el reto")
            .setSmallIcon(android.R.drawable.ic_lock_alarm)
            .setContentIntent(pi)
            .setFullScreenIntent(pi, true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            val audioAttr = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val channel = NotificationChannel(CHANNEL_ID, "Alarmas WAKE UP",
                NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Notificaciones de alarma"
                setBypassDnd(true)      // ← IGNORA MODO NO MOLESTAR
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(true)
                setSound(alarmUri, audioAttr)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300, 200, 500)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun stopSound() {
        mediaPlayer?.let {
            try { if (it.isPlaying) it.stop() } catch (_: Exception) {}
            it.release()
        }
        mediaPlayer = null
    }

    override fun onDestroy() {
        stopSound()
        try { wakeLock?.release() } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?) = null
}
