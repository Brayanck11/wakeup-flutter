package com.wakeup.alarm

import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.wakeup.alarm/ringtone"
    private var mediaPlayer: MediaPlayer? = null
    private var audioManager: AudioManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playRingtone" -> {
                    val uri = call.argument<String>("uri")
                    val volume = call.argument<Double>("volume") ?: 1.0
                    val loop = call.argument<Boolean>("loop") ?: true
                    playRingtone(uri, volume.toFloat(), loop)
                    result.success(null)
                }
                "stopRingtone" -> {
                    stopRingtone()
                    result.success(null)
                }
                "setVolume" -> {
                    val volume = call.argument<Double>("volume") ?: 1.0
                    setVolume(volume.toFloat())
                    result.success(null)
                }
                "getSystemRingtones" -> {
                    result.success(getSystemRingtones())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun playRingtone(uriString: String?, volume: Float, loop: Boolean) {
        try {
            stopRingtone()
            val uri: Uri = when {
                uriString.isNullOrEmpty() || uriString == "default_alarm" || uriString == "beep" ->
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                uriString == "default_ringtone" ->
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                uriString.startsWith("content://") || uriString.startsWith("android.resource://") ->
                    Uri.parse(uriString)
                uriString.startsWith("/") ->
                    Uri.parse("file://$uriString")
                else ->
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            }

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                )
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
                    isLooping = loop
                    setVolume(volume, volume)
                    prepare()
                    start()
                }
            } catch (ex: Exception) { ex.printStackTrace() }
        }
    }

    private fun setVolume(volume: Float) {
        mediaPlayer?.setVolume(volume, volume)
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
