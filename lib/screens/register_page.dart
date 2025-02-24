import 'package:chatsys/models/user_model.dart';
import 'package:chatsys/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:chatsys/screens/profile_setup_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatsys/screens/contacts_screen.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLogin = true;

  void _toggleFormMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  Future<void> _submitForm() async {
    try {
      UserModel? result;
      if (_isLogin) {
        // Existing sign-in logic
        final userCredential = await _authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (userCredential != null) {
          // Fetch the user model from Firestore
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();

          if (userDoc.exists && userDoc.data()?['displayName'] != null) {
            // User exists and has a complete profile, navigate to contacts screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ContactsScreen()),
            );
          } else {
            // User exists in auth but not in Firestore or profile is incomplete
            final userModel = UserModel(
              id: userCredential.user!.uid,
              email: userCredential.user!.email!,
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ProfileSetupPage(initialUser: userModel),
              ),
            );
          }
        }
      } else {
        // Registration logic
        final userModel = await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (userModel != null) {
          // Always navigate to profile setup after registration
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ProfileSetupPage(initialUser: userModel),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final result = await _authService.signInWithGoogle();
      if (result != null) {
        // Check if user has a complete profile in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(result.id)
            .get();

        if (userDoc.exists && userDoc.data()?['displayName'] != null) {
          // User has a complete profile, navigate to contacts screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ContactsScreen()),
          );
        } else {
          // Navigate to profile setup
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ProfileSetupPage(initialUser: result),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _signInWithFacebook() async {
    try {
      final result = await _authService.signInWithFacebook();
      if (result != null) {
        // Check if user has a complete profile in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(result.id)
            .get();

        if (userDoc.exists && userDoc.data()?['displayName'] != null) {
          // User has a complete profile, navigate to contacts screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ContactsScreen()),
          );
        } else {
          // Navigate to profile setup
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ProfileSetupPage(initialUser: result),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text(_isLogin ? 'Login' : 'Register'),
              ),
              TextButton(
                onPressed: _toggleFormMode,
                child: Text(_isLogin
                    ? 'Need an account? Register'
                    : 'Already have an account? Login'),
              ),
              const Divider(),
              const Text('Or sign in with:'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const FaIcon(FontAwesomeIcons.google,
                        color: Colors.white),
                    label: const Text('Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _signInWithFacebook,
                    icon: const FaIcon(FontAwesomeIcons.facebook,
                        color: Colors.white),
                    label: const Text('Facebook'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
