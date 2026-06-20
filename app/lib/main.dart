import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "services/api_service.dart";
import "screens/login_screen.dart";
import "screens/home_screen.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  final loggedIn = await ApiService.init();
  runApp(EasyCallApp(loggedIn: loggedIn));
}

class EasyCallApp extends StatelessWidget {
  final bool loggedIn;
  const EasyCallApp({super.key, required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "EasyCall",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: loggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
