import 'dart:io' show SocketException, InternetAddress;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatsys/auth/register_page.dart';
import 'package:chatsys/pages/contacts_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/rendering.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Add a method to handle network connectivity
  //bool _isNetworkAvailable = true;

  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // Enhanced error handling for authentication methods
  void _showDetailedErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title, style: TextStyle(color: Colors.red[700])),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
              if (title == 'Network Error')
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Optionally open device settings
                  },
                  child: const Text('Open Settings'),
                ),
            ],
          ),
    );
  }

  // Add user to Firestore collection
  Future<void> _addUserToFirestore(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName ?? 'User',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error adding user to Firestore: $e');
    }
  }

  // Email/Password Login with enhanced error handling
  Future<void> _loginWithEmail() async {
    // Check network connectivity first
    final networkStatus = await _checkNetworkConnectivity();
    if (!networkStatus) {
      _showDetailedErrorDialog(
        'Network Error',
        'No internet connection. Please check your network settings.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // Update user in Firestore
      await _addUserToFirestore(userCredential.user!);

      // Safe navigation
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ContactsPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email. Please register.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format. Please check your email.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Contact support.';
          break;
        default:
          errorMessage =
              e.message ?? 'An unexpected authentication error occurred.';
      }
      _showDetailedErrorDialog('Login Failed', errorMessage);
    } catch (e) {
      _showDetailedErrorDialog(
        'Unexpected Error',
        'Something went wrong. Please try again later.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Google Sign-In with enhanced error handling
  Future<void> _signInWithGoogle() async {
    // Check network connectivity first
    final networkStatus = await _checkNetworkConnectivity();
    if (!networkStatus) {
      _showDetailedErrorDialog(
        'Network Error',
        'No internet connection. Please check your network settings.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return;
      }

      final GoogleSignInAuthentication? googleAuth =
          await googleUser.authentication;

      if (googleAuth == null) {
        _showDetailedErrorDialog(
          'Google Sign-In Failed',
          'Unable to authenticate with Google. Please try again.',
        );
        return;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      // Add/Update user in Firestore
      await _addUserToFirestore(userCredential.user!);

      // Safe navigation
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ContactsPage()),
        );
      }
    } catch (e) {
      _showDetailedErrorDialog(
        'Google Sign-In Failed',
        'An error occurred during Google authentication. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Facebook Sign-In with enhanced error handling
  Future<void> _signInWithFacebook() async {
    // Check network connectivity first
    final networkStatus = await _checkNetworkConnectivity();
    if (!networkStatus) {
      _showDetailedErrorDialog(
        'Network Error',
        'No internet connection. Please check your network settings.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final LoginResult result = await FacebookAuth.instance.login();

      switch (result.status) {
        case LoginStatus.success:
          if (result.accessToken != null) {
            final OAuthCredential credential = FacebookAuthProvider.credential(
              result.accessToken!.tokenString,
            );

            final UserCredential userCredential = await FirebaseAuth.instance
                .signInWithCredential(credential);

            // Add/Update user in Firestore
            await _addUserToFirestore(userCredential.user!);

            // Safe navigation
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ContactsPage()),
              );
            }
          }
          break;
        case LoginStatus.cancelled:
          _showDetailedErrorDialog(
            'Facebook Sign-In',
            'Sign-in was cancelled by the user.',
          );
          break;
        case LoginStatus.failed:
          _showDetailedErrorDialog(
            'Facebook Sign-In Failed',
            result.message ?? 'Authentication failed. Please try again.',
          );
          break;
        case LoginStatus.operationInProgress:
          _showDetailedErrorDialog(
            'Facebook Sign-In',
            'Another sign-in operation is in progress.',
          );
          break;
      }
    } catch (e) {
      _showDetailedErrorDialog(
        'Facebook Sign-In Failed',
        'An unexpected error occurred. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Apple Sign-In with enhanced error handling
  Future<void> _signInWithApple() async {
    // Check network connectivity first
    final networkStatus = await _checkNetworkConnectivity();
    if (!networkStatus) {
      _showDetailedErrorDialog(
        'Network Error',
        'No internet connection. Please check your network settings.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final appleCredential = oAuthProvider.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(appleCredential);

      // Add/Update user in Firestore
      await _addUserToFirestore(userCredential.user!);

      // Safe navigation
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ContactsPage()),
        );
      }
    } catch (e) {
      _showDetailedErrorDialog(
        'Apple Sign-In Failed',
        'An error occurred during Apple authentication. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_isPasswordVisible,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _loginWithEmail,
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Login'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // TODO: Implement password reset functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset coming soon')),
                  );
                },
                child: const Text('Forgot Password?'),
              ),
              const SizedBox(height: 16),
              const Text('Or login with:', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(
                      FontAwesomeIcons.google,
                      size: 48,
                      color: Colors.green,
                    ),
                    onPressed: _isLoading ? null : _signInWithGoogle,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.facebook,
                      size: 48,
                      color: Colors.blue,
                    ),
                    onPressed: _isLoading ? null : _signInWithFacebook,
                  ),
                  IconButton(
                    icon: const Icon(Icons.apple, size: 48),
                    onPressed: _isLoading ? null : _signInWithApple,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Don\'t have an account?'),
                  TextButton(
                    onPressed: () {
                      // Navigate to Registration Page
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      );
                    },
                    child: const Text('Register'),
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
