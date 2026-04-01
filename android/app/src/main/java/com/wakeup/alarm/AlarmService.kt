package com.wakeup.alarm

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.*
import androidx.core.app.NotificationCompat

class AlarmService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val CHANNEL_ID = "wakeup_alarm_channel"
    private val NOTIF_ID = 1001

    companion object {
        var isRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val label  = intent?.getStringExtra("label")   ?: "WAKE UP"
        val sound  = intent?.getStringExtra("sound")   ?: ""
        val gradual = intent?.getBooleanExtra("gradual", false) ?: false

        // Notificación que al tocarla abre la app con el reto
        val openIntent = Intent(this, MainActivity::class.java).apply {
            action = "FIRE_ALARM"
            flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("alarm_label",   label)
            putExtra("alarm_sound",   sound)
            putExtra("alarm_gradual", gradual)
        }
        val pi = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("⏰ $label")
            .setContentText("Toca para resolver el reto y apagar la alarma")
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentIntent(pi)
            .setFullScreenIntent(pi, true)   // ← muestra en pantalla de bloqueo
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)                // ← no se puede deslizar para cerrar
            .setAutoCancel(false)
            .build()

        startForeground(NOTIF_ID, notification)

        // Reproducir sonido — NO se detiene solo, solo se detiene cuando
        // el usuario resuelve el reto o pulsa posponer
        playSound(sound, gradual)
        vibrate()

        return START_STICKY
    }

    private fun playSound(soundUri: String, gradual: Boolean) {
        stopSound()
        try {
            val uri: Uri = resolveUri(soundUri)
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
            if (gradual) rampVolume()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun resolveUri(s: String): Uri {
        return when {
            s.isEmpty() || s == "beep" || s == "default_alarm" ->
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            s == "default_ringtone" ->
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            s.startsWith("content://") -> Uri.parse(s)
            s.startsWith("/")          -> Uri.parse("file://$s")
            else -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        }
    }

    private fun rampVolume() {
        val handler = Handler(Looper.getMainLooper())
        var vol = 0.05f
        val r = object : Runnable {
            override fun run() {
                vol = (vol + 0.1f).coerceAtMost(1.0f)
                mediaPlayer?.setVolume(vol, vol)
                if (vol < 1.0f) handler.postDelayed(this, 2000)
            }
        }
        handler.postDelayed(r, 2000)
    }

    private fun vibrate() {
        try {
            val pattern = longArrayOf(0, 400, 200, 400, 200, 600)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v.vibrate(VibrationEffect.createWaveform(pattern, 0))
                } else {
                    @Suppress("DEPRECATION")
                    v.vibrate(pattern, 0)
                }
            }
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "WakeUp::AlarmWakeLock"
            ).apply { acquire(15 * 60 * 1000L) }
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Alarmas WAKE UP", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setBypassDnd(true)             // ← ignora modo no molestar
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(true)
                setShowBadge(true)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
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
        isRunning = false
        stopSound()
        try { wakeLock?.release() } catch (_: Exception) {}
        // Cancelar vibración
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                    .defaultVibrator.cancel()
            } else {
                @Suppress("DEPRECATION")
                (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
            }
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?) = null
}
