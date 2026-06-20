package com.easycall.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;

/**
 * 前台服务 - 用于保持 App 在后台时仍能在线
 * 需要在应用启动时调用 startForegroundService()
 */
public class EasyCallForegroundService extends Service {

    private static final String CHANNEL_ID = "easycall_online";
    private static final int NOTIFICATION_ID = 1001;

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Notification notification = new Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("EasyCall")
                .setContentText("在线中，可接收视频通话和远程协助")
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setOngoing(true)
                .build();

        startForeground(NOTIFICATION_ID, notification);
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "在线状态",
                    NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("显示 EasyCall 在线状态通知");
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) manager.createNotificationChannel(channel);
        }
    }
}
