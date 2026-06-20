package com.easycall.app;
import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
public class MainActivity extends FlutterActivity {
  private static final String CHANNEL="com.easycall.app/accessibility";
  private static final String CHANNEL_REMOTE="com.easycall.app/remote";
  @Override public void configureFlutterEngine(FlutterEngine e){
    super.configureFlutterEngine(e);
    new MethodChannel(e.getDartExecutor().getBinaryMessenger(),CHANNEL).setMethodCallHandler((c,r)->{
      EasyCallAccessibilityService s=EasyCallAccessibilityService.getInstance();
      switch(c.method){
        case "isEnabled":r.success(s!=null);break;
        case "tap":{double x=c.argument("x");double y=c.argument("y");r.success(s!=null&&s.simulateTap((float)x,(float)y));break;}
        case "swipe":{double x1=c.argument("x1"),y1=c.argument("y1"),x2=c.argument("x2"),y2=c.argument("y2");int d=c.argument("duration");r.success(s!=null&&s.simulateSwipe((float)x1,(float)y1,(float)x2,(float)y2,d));break;}
        case "pressBack":r.success(s!=null&&s.pressBack());break;
        case "pressHome":r.success(s!=null&&s.pressHome());break;
        default:r.notImplemented();
      }
    });
    new MethodChannel(e.getDartExecutor().getBinaryMessenger(),CHANNEL_REMOTE).setMethodCallHandler((c,r)->{
      switch(c.method){
        case "playVideo":{String url=c.argument("url");if(url!=null){android.content.Intent i=new android.content.Intent(android.content.Intent.ACTION_VIEW);i.setData(android.net.Uri.parse(url));i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK);startActivity(i);r.success(true);}else r.error("NO_URL","",null);break;}
        case "startForeground":{android.content.Intent i=new android.content.Intent(this,EasyCallForegroundService.class);if(android.os.Build.VERSION.SDK_INT>=android.os.Build.VERSION_CODES.O)startForegroundService(i);else startService(i);r.success(true);break;}
        default:r.notImplemented();
      }
    });
  }
}
