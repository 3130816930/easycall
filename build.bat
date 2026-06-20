@echo off
chcp 65001 >nul
title EasyCall APK Builder

echo ╔══════════════════════════════════════════════════╗
echo ║         EasyCall APK 构建工具                    ║
echo ╚══════════════════════════════════════════════════╝
echo.

:: Check Flutter
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 未找到 Flutter SDK
    echo.
    echo 请先安装 Flutter:
    echo   1. 访问 https://flutter.dev/docs/get-started/install/windows
    echo   2. 下载 Flutter SDK ZIP
    echo   3. 解压到 C:\flutter
    echo   4. 将 C:\flutter\bin 添加到系统 PATH
    echo   5. 运行 flutter doctor 检查环境
    echo.
    echo 安装完成后重新运行此脚本
    pause
    exit /b 1
)

echo ✅ Flutter 已安装
echo.

:: Go to app directory
cd /d "%~dp0app"
echo 📂 进入目录: %CD%
echo.

:: Get dependencies
echo 📦 安装依赖...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 依赖安装失败
    pause
    exit /b 1
)
echo ✅ 依赖安装完成
echo.

:: Check connected devices
echo 📱 检查连接的设备...
call flutter devices
echo.

:: Ask user for build type
echo ⚙️ 请选择构建方式:
echo   1. APK (安装包，推荐)
echo   2. 直接安装到连接的手机
echo.
set /p choice="请输入数字 (1 或 2): "

if "%choice%"=="1" (
    echo.
    echo 🔨 正在构建 APK...
    call flutter build apk --release
    if %ERRORLEVEL% NEQ 0 (
        echo ❌ 构建失败
        pause
        exit /b 1
    )
    echo.
    echo ✅ 构建成功!
    echo 📍 APK 位置: build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo 将 APK 复制到手机安装即可使用
) else if "%choice%"=="2" (
    echo.
    echo 📲 正在安装到手机...
    call flutter run --release
) else (
    echo ❌ 无效输入
)

echo.
pause
