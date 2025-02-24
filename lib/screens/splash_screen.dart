import 'package:chatsys/models/user_model.dart';
import 'package:chatsys/screens/contacts_screen.dart';
import 'package:chatsys/screens/login_screen.dart';
import 'package:chatsys/screens/profile_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  Future<void> _checkAuthenticationStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    final FirebaseAuth auth = FirebaseAuth.instance;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    User? currentUser = auth.currentUser;

    if (currentUser == null) {
      // No user logged in
      _navigateTo(const LoginScreen());
    } else {
      try {
        // Check if user exists in Firestore
        final userDoc =
            await firestore.collection('users').doc(currentUser.uid).get();

        if (userDoc.exists) {
          // User exists and has a complete profile
          _navigateTo(const ContactsScreen());
        } else {
          // User exists in auth but needs profile setup
          final userModel = UserModel(
            id: currentUser.uid,
            email: currentUser.email!,
          );
          _navigateTo(ProfileSetupPage(initialUser: userModel));
        }
      } catch (e) {
        // Error checking user, default to login
        _navigateTo(const LoginScreen());
      }
    }
  }

  void _navigateTo(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.blue, // Customize your splash screen background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your app logo or icon
            FlutterLogo(size: 100),
            SizedBox(height: 20),
            Text(
              'Video Chat App',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
