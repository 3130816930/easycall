var f=require("fs");
var m=f.readFileSync("D:/app/easycall/app/android/app/src/main/AndroidManifest.xml","utf8");
m=m.replace("</application>",'<meta-data android:name="flutterEmbedding" android:value="2"/></application>');
f.writeFileSync("D:/app/easycall/app/android/app/src/main/AndroidManifest.xml",m,"utf8");
console.log("Added flutterEmbedding meta-data");

// Also verify appearance at first glance
var r=f.readFileSync("D:/app/easycall/app/android/app/src/main/res/values/styles.xml","utf8");
console.log("styles.xml:", r.substring(0,200));
