package com.easycall.app;

import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "com.easycall.app/accessibility";
    private static final String CHANNEL_REMOTE = "com.easycall.app/remote";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // ── 辅助功能控制通道 ──
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    EasyCallAccessibilityService service = EasyCallAccessibilityService.getInstance();

                    switch (call.method) {
                        case "isEnabled":
                            // 检查无障碍服务是否已启用
                            result.success(service != null);
                            break;

                        case "tap":
                            double x = call.argument("x");
                            double y = call.argument("y");
                            if (service != null) {
                                boolean ok = service.simulateTap((float) x, (float) y);
                                result.success(ok);
                            } else {
                                result.error("SERVICE_NOT_ENABLED", "请先在系统设置中启用 EasyCall 辅助功能", null);
                            }
                            break;

                        case "swipe":
                            double x1 = call.argument("x1");
                            double y1 = call.argument("y1");
                            double x2 = call.argument("x2");
                            double y2 = call.argument("y2");
                            int duration = call.argument("duration");
                            if (service != null) {
                                boolean ok = service.simulateSwipe(
                                        (float) x1, (float) y1, (float) x2, (float) y2, duration);
                                result.success(ok);
                            } else {
                                result.error("SERVICE_NOT_ENABLED", "请先启用辅助功能", null);
                            }
                            break;

                        case "pressBack":
                            result.success(service != null && service.pressBack());
                            break;

                        case "pressHome":
                            result.success(service != null && service.pressHome());
                            break;

                        case "pressRecent":
                            result.success(service != null && service.pressRecent());
                            break;

                        default:
                            result.notImplemented();
                    }
                });

        // ── 远程控制命令通道（如播放视频、调整音量等） ──
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_REMOTE)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "playVideo":
                            String url = call.argument("url");
                            String title = call.argument("title");
                            if (url != null) {
                                Intent intent = new Intent(Intent.ACTION_VIEW);
                                intent.setData(android.net.Uri.parse(url));
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                startActivity(intent);
                                result.success(true);
                            } else {
                                result.error("NO_URL", "未提供视频 URL", null);
                            }
                            break;

                        case "openApp":
                            String pkg = call.argument("package");
                            if (pkg != null) {
                                Intent intent = getPackageManager().getLaunchIntentForPackage(pkg);
                                if (intent != null) {
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                    startActivity(intent);
                                    result.success(true);
                                } else {
                                    result.error("APP_NOT_FOUND", "未找到应用: " + pkg, null);
                                }
                            }
                            break;

                        case "startForeground":
                            // 启动前台服务保持在线
                            Intent serviceIntent = new Intent(this, EasyCallForegroundService.class);
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(serviceIntent);
                            } else {
                                startService(serviceIntent);
                            }
                            result.success(true);
                            break;

                        default:
                            result.notImplemented();
                    }
                });
    }
}
