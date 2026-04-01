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
        val id = intent.getIntExtra("id", -1)

        // 1. Iniciar foreground service para sonar inmediatamente
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra("label", label)
            putExtra("sound", sound)
            putExtra("gradual", gradual)
            putExtra("id", id)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }

        // 2. Abrir la app con los datos de la alarma para mostrar el reto
        val appIntent = Intent(context, MainActivity::class.java).apply {
            action = "FIRE_ALARM"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("alarm_label", label)
            putExtra("alarm_sound", sound)
            putExtra("alarm_gradual", gradual)
            putExtra("alarm_id", id)
        }
        context.startActivity(appIntent)
    }
}
