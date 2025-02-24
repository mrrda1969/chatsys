import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'theme_provider.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize FacebookAuth
  // await FacebookAuth.instance.autoLogAppEvents();
  // await FacebookAuth.instance.init(
  //   options: const FacebookOptions(
  //     appId: 'YOUR_FACEBOOK_APP_ID',
  //     clientToken: 'YOUR_CLIENT_TOKEN',
  //     loginBehavior: LoginBehavior.nativeWithFallback, // Recommended
  //   ),
  // );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark
            ? darkTheme
            : lightTheme,
      ),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChatSys',
      theme: themeProvider.themeData,
      home: const SplashScreen(),
    );
  }
}
