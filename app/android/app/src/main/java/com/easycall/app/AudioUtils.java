package com.easycall.app;

import android.content.Context;
import android.media.AudioManager;

/** 音量调节工具 */
public class AudioUtils {
    public static void adjustVolume(Context context, boolean up) {
        AudioManager audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        if (audio != null) {
            int direction = up ? AudioManager.ADJUST_RAISE : AudioManager.ADJUST_LOWER;
            audio.adjustStreamVolume(AudioManager.STREAM_MUSIC, direction, AudioManager.FLAG_SHOW_UI);
        }
    }
}
