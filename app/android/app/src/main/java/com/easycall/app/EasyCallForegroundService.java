package com.easycall.app;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
public class EasyCallForegroundService extends Service {
  private static final String CHANNEL_ID="easycall_online";
  private static final int NOTIFY_ID=1001;
  @Override public void onCreate(){super.onCreate();if(Build.VERSION.SDK_INT>=Build.VERSION_CODES.O){NotificationChannel c=new NotificationChannel(CHANNEL_ID,"Online",NotificationManager.IMPORTANCE_LOW);c.setDescription("Shows EasyCall online status");NotificationManager m=getSystemService(NotificationManager.class);if(m!=null)m.createNotificationChannel(c);}}
  @Override public int onStartCommand(Intent i,int f,int sid){Notification n=new Notification.Builder(this,CHANNEL_ID).setContentTitle("EasyCall").setContentText("Online - ready for calls and remote help").setSmallIcon(android.R.drawable.ic_menu_call).setOngoing(true).build();startForeground(NOTIFY_ID,n);return START_STICKY;}
  @Override public IBinder onBind(Intent i){return null;}
}
