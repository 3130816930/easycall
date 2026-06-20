var fs=require("fs");

// === 1. settings.gradle ===
var settings='include ":app"\n\n'+
'def localPropertiesFile = new File(rootProject.projectDir, "local.properties")\n'+
'def properties = new Properties()\n\n'+
'assert localPropertiesFile.exists()\n'+
'localPropertiesFile.withInputStream { properties.load(it) }\n\n'+
'def flutterSdkPath = properties.getProperty("flutter.sdk")\n'+
'assert flutterSdkPath != null, "flutter.sdk not set in local.properties"\n'+
'apply from: "$flutterSdkPath/packages/flutter_tools/gradle/app_plugin_loader.gradle"\n';
fs.writeFileSync("D:/app/easycall/app/android/settings.gradle", settings, "utf8");
console.log("✅ settings.gradle");

// === 2. app/build.gradle ===
var appBuild='plugins {\n'+
'    id "com.android.application"\n'+
'}\n\n'+
'def localProperties = new Properties()\n'+
'def localPropertiesFile = rootProject.file("local.properties")\n'+
'if (localPropertiesFile.exists()) {\n'+
'    localPropertiesFile.withInputStream { stream ->\n'+
'        localProperties.load(stream)\n'+
'    }\n'+
'}\n\n'+
'def flutterRoot = localProperties.getProperty("flutter.sdk")\n'+
'if (flutterRoot == null) {\n'+
'    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")\n'+
'}\n\n'+
'apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"\n\n'+
'android {\n'+
'    namespace "com.easycall.app"\n'+
'    compileSdk 34\n\n'+
'    compileOptions {\n'+
'        sourceCompatibility JavaVersion.VERSION_1_8\n'+
'        targetCompatibility JavaVersion.VERSION_1_8\n'+
'    }\n\n'+
'    defaultConfig {\n'+
'        applicationId "com.easycall.app"\n'+
'        minSdk 21\n'+
'        targetSdk 34\n'+
'        versionCode 1\n'+
'        versionName "1.0.0"\n'+
'        multiDexEnabled true\n'+
'    }\n\n'+
'    buildTypes {\n'+
'        release {\n'+
'            minifyEnabled false\n'+
'        }\n'+
'    }\n'+
'}\n\n'+
'flutter {\n'+
'    source "../.."\n'+
'}\n\n'+
'dependencies {\n'+
'    implementation "androidx.multidex:multidex:2.0.1"\n'+
'}\n';
fs.writeFileSync("D:/app/easycall/app/android/app/build.gradle", appBuild, "utf8");
console.log("✅ app/build.gradle");

// === 3. project build.gradle ===
var projBuild='allprojects {\n'+
'    repositories {\n'+
'        google()\n'+
'        mavenCentral()\n'+
'    }\n'+
'}\n\n'+
'rootProject.buildDir = "../build"\n'+
'subprojects {\n'+
'    project.buildDir = "${rootProject.buildDir}/${project.name}"\n'+
'}\n'+
'subprojects {\n'+
'    project.evaluationDependsOn(":app")\n'+
'}\n\n'+
'tasks.register("clean", Delete) {\n'+
'    delete rootProject.buildDir\n'+
'}\n';
fs.writeFileSync("D:/app/easycall/app/android/build.gradle", projBuild, "utf8");
console.log("✅ project build.gradle");

// === 4. Verify AndroidManifest has flutterEmbedding ===
var m=fs.readFileSync("D:/app/easycall/app/android/app/src/main/AndroidManifest.xml", "utf8");
if(m.indexOf("flutterEmbedding")<0){
  m=m.replace("</application>",'<meta-data android:name="flutterEmbedding" android:value="2"/></application>');
  fs.writeFileSync("D:/app/easycall/app/android/app/src/main/AndroidManifest.xml", m, "utf8");
  console.log("✅ AndroidManifest.xml - added flutterEmbedding");
} else {
  console.log("✅ AndroidManifest.xml - already has flutterEmbedding");
}

console.log("\\nAll Android build files updated!");
