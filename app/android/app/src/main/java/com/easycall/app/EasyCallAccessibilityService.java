package com.easycall.app;
import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.graphics.Path;
import android.os.Build;
import android.view.accessibility.AccessibilityNodeInfo;
public class EasyCallAccessibilityService extends AccessibilityService {
  private static EasyCallAccessibilityService instance;
  @Override public void onAccessibilityEvent(android.view.accessibility.AccessibilityEvent e){}
  @Override public void onInterrupt(){}
  @Override public void onCreate(){super.onCreate();instance=this;}
  @Override public void onDestroy(){super.onDestroy();instance=null;}
  public static EasyCallAccessibilityService getInstance(){return instance;}
  public boolean simulateTap(float x,float y){if(Build.VERSION.SDK_INT<24)return false;Path p=new Path();p.moveTo(x,y);GestureDescription.StrokeDescription s=new GestureDescription.StrokeDescription(p,0,100);GestureDescription.Builder b=new GestureDescription.Builder();b.addStroke(s);return dispatchGesture(b.build(),null,null);}
  public boolean simulateSwipe(float x1,float y1,float x2,float y2,int ms){if(Build.VERSION.SDK_INT<24)return false;Path p=new Path();p.moveTo(x1,y1);p.lineTo(x2,y2);GestureDescription.StrokeDescription s=new GestureDescription.StrokeDescription(p,0,ms);GestureDescription.Builder b=new GestureDescription.Builder();b.addStroke(s);return dispatchGesture(b.build(),null,null);}
  public boolean pressBack(){return performGlobalAction(GLOBAL_ACTION_BACK);}
  public boolean pressHome(){return performGlobalAction(GLOBAL_ACTION_HOME);}
}
