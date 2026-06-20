var fs=require("fs");

// Fix call_screen.dart
var c=fs.readFileSync("D:/app/easycall/app/lib/screens/call_screen.dart","utf8");
if(c.indexOf("flutter_webrtc")<0){
  c=c.replace(
    'import "../services/webrtc_service.dart";',
    'import "../services/webrtc_service.dart";\nimport "package:flutter_webrtc/flutter_webrtc.dart";'
  );
}
// Remove dart:io import (use regex)
c=c.replace(/import[^;]*dart:io[^;]*;/g,"");
fs.writeFileSync("D:/app/easycall/app/lib/screens/call_screen.dart",c,"utf8");
console.log("call_screen done");

// Fix remote_control_screen.dart
var r=fs.readFileSync("D:/app/easycall/app/lib/screens/remote_control_screen.dart","utf8");
if(r.indexOf("flutter_webrtc")<0){
  r=r.replace(
    'import "../services/remote_control_service.dart";',
    'import "../services/remote_control_service.dart";\nimport "package:flutter_webrtc/flutter_webrtc.dart";'
  );
}
if(r.indexOf("ApiService")>=0 && r.indexOf("api_service.dart")<0){
  r=r.replace(
    'import "../services/websocket_service.dart";',
    'import "../services/websocket_service.dart";\nimport "../services/api_service.dart";'
  );
}
fs.writeFileSync("D:/app/easycall/app/lib/screens/remote_control_screen.dart",r,"utf8");
console.log("remote_control_screen done");

// Fix pubspec.yaml
var y=fs.readFileSync("D:/app/easycall/app/pubspec.yaml","utf8");
if(y.indexOf("flutter_webrtc: ^0.9.52")>=0){
  y=y.replace("flutter_webrtc: ^0.9.52","flutter_webrtc: ^0.11.1");
  fs.writeFileSync("D:/app/easycall/app/pubspec.yaml",y,"utf8");
  console.log("pubspec updated");
}

// Fix home_screen.dart remove dart:io
var h=fs.readFileSync("D:/app/easycall/app/lib/screens/home_screen.dart","utf8");
h=h.replace(/import[^;]*dart:io[^;]*;/g,"");
fs.writeFileSync("D:/app/easycall/app/lib/screens/home_screen.dart",h,"utf8");
console.log("home_screen done");

console.log("ALL DONE");
