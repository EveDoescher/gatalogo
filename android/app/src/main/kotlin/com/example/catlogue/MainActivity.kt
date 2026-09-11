package com.example.catlogue

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "gatalogo_alerts",
                "Alertas do Gatálogo",
                NotificationManager.IMPORTANCE_HIGH,
            )
            channel.description = "Possíveis avistamentos, mensagens e atualizações importantes."
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
