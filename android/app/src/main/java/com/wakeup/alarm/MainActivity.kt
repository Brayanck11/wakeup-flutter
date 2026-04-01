package com.wakeup.alarm

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.wakeup.alarm/ringtone"
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playRingtone" -> {
                    playRingtone(call.argument<String>("uri"))
                    result.success(null)
                }
                "stopRingtone" -> {
                    stopRingtone()
                    result.success(null)
                }
                "getSystemRingtones" -> {
                    result.success(getSystemRingtones())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun playRingtone(uriString: String?) {
        try {
            stopRingtone()
            val uri: Uri = when {
                uriString.isNullOrEmpty() || uriString == "default_alarm" ->
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                uriString == "default_ringtone" ->
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                else -> Uri.parse(uriString)
            }
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build())
                setDataSource(applicationContext, uri)
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            try {
                val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(applicationContext, defaultUri)
                    isLooping = true
                    prepare()
                    start()
                }
            } catch (ex: Exception) { ex.printStackTrace() }
        }
    }

    private fun stopRingtone() {
        mediaPlayer?.let { if (it.isPlaying) it.stop(); it.release() }
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
