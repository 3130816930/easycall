package com.easycall.app;
import android.content.Context;
import android.media.AudioManager;
public class AudioUtils {
  public static void adjustVolume(Context c,boolean up){AudioManager a=(AudioManager)c.getSystemService(Context.AUDIO_SERVICE);if(a!=null)a.adjustStreamVolume(AudioManager.STREAM_MUSIC,up?AudioManager.ADJUST_RAISE:AudioManager.ADJUST_LOWER,AudioManager.FLAG_SHOW_UI);}
}
