package com.easycall.app;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.content.Intent;
import android.graphics.Path;
import android.graphics.Rect;
import android.os.Build;
import android.os.Bundle;
import android.view.accessibility.AccessibilityNodeInfo;
import java.util.List;

/**
 * EasyCall 辅助功能服务
 * 用于远程控制中模拟触摸操作
 *
 * 使用方式：
 * 1. 用户需在系统设置 -> 辅助功能中启用 "EasyCall"
 * 2. 该服务接收来自 Flutter 层的远程命令
 * 3. 通过 Flutter MethodChannel 执行触摸模拟
 */
public class EasyCallAccessibilityService extends AccessibilityService {

    private static EasyCallAccessibilityService instance;

    @Override
    public void onAccessibilityEvent(android.view.accessibility.AccessibilityEvent event) {
        // 事件监听，暂不作为主要功能
    }

    @Override
    public void onInterrupt() {
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        instance = null;
    }

    public static EasyCallAccessibilityService getInstance() {
        return instance;
    }

    // ── 模拟点击 ──
    public boolean simulateTap(float x, float y) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false;

        Path path = new Path();
        path.moveTo(x, y);

        GestureDescription.StrokeDescription stroke =
                new GestureDescription.StrokeDescription(path, 0, 100);

        GestureDescription.Builder builder = new GestureDescription.Builder();
        builder.addStroke(stroke);

        return dispatchGesture(builder.build(), null, null);
    }

    // ── 模拟长按 ──
    public boolean simulateLongPress(float x, float y, long durationMs) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false;

        Path path = new Path();
        path.moveTo(x, y);

        GestureDescription.StrokeDescription stroke =
                new GestureDescription.StrokeDescription(path, 0, durationMs);

        GestureDescription.Builder builder = new GestureDescription.Builder();
        builder.addStroke(stroke);

        return dispatchGesture(builder.build(), null, null);
    }

    // ── 模拟滑动 ──
    public boolean simulateSwipe(float x1, float y1, float x2, float y2, int durationMs) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false;

        Path path = new Path();
        path.moveTo(x1, y1);
        path.lineTo(x2, y2);

        GestureDescription.StrokeDescription stroke =
                new GestureDescription.StrokeDescription(path, 0, durationMs);

        GestureDescription.Builder builder = new GestureDescription.Builder();
        builder.addStroke(stroke);

        return dispatchGesture(builder.build(), null, null);
    }

    // ── 执行全局动作（返回、主页、最近任务） ──
    public boolean performGlobalAction(int action) {
        return performGlobalAction(action);
    }

    // ── 模拟返回键 ──
    public boolean pressBack() {
        return performGlobalAction(GLOBAL_ACTION_BACK);
    }

    // ── 模拟 Home 键 ──
    public boolean pressHome() {
        return performGlobalAction(GLOBAL_ACTION_HOME);
    }

    // ── 模拟最近任务键 ──
    public boolean pressRecent() {
        return performGlobalAction(GLOBAL_ACTION_RECENTS);
    }

    // ── 模拟音量键 ──
    public boolean pressVolumeUp() {
        // 通过系统 API 调节音量
        AudioUtils.adjustVolume(this, true);
        return true;
    }

    public boolean pressVolumeDown() {
        AudioUtils.adjustVolume(this, false);
        return true;
    }

    // ── 查找并点击文本（辅助功能定位 UI 元素） ──
    public boolean clickByText(String text) {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) return false;

        List<AccessibilityNodeInfo> nodes = root.findAccessibilityNodeInfosByText(text);
        if (nodes != null && !nodes.isEmpty()) {
            AccessibilityNodeInfo target = nodes.get(0);
            if (target.isClickable()) {
                target.performAction(AccessibilityNodeInfo.ACTION_CLICK);
                return true;
            }
            // 向上查找可点击的父节点
            AccessibilityNodeInfo parent = target;
            while (parent != null) {
                if (parent.isClickable()) {
                    parent.performAction(AccessibilityNodeInfo.ACTION_CLICK);
                    return true;
                }
                parent = parent.getParent();
            }
        }
        return false;
    }
}
