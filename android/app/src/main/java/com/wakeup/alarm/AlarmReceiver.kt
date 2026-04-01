package com.wakeup.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val label = intent.getStringExtra("label") ?: "WAKE UP"
        val sound = intent.getStringExtra("sound") ?: ""
        val gradual = intent.getBooleanExtra("gradual", false)

        // Iniciar el foreground service de alarma
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra("label", label)
            putExtra("sound", sound)
            putExtra("gradual", gradual)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }

        // Abrir la app para mostrar el reto
        val appIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("alarm_label", label)
            putExtra("alarm_sound", sound)
            action = "FIRE_ALARM"
        }
        context.startActivity(appIntent)
    }
}
