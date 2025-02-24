import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:chatsys/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream of authentication state changes
  Stream<User?> get user => _auth.authStateChanges();

  // Create or update user profile in Firestore
  Future<UserModel> createOrUpdateUserProfile({
    required String userId,
    required String email,
    String? displayName,
    File? profileImage,
  }) async {
    try {
      String? profilePictureUrl;

      // Upload profile picture if provided
      if (profileImage != null) {
        try {
          final storageRef =
              _storage.ref().child('profile_pictures/$userId.jpg');

          // Use putData instead of putFile to avoid potential file reference issues
          final uploadTask = await storageRef.putData(
            await profileImage.readAsBytes(),
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'user_id': userId,
                'upload_type': 'profile_picture'
              },
            ),
          );

          profilePictureUrl = await uploadTask.ref.getDownloadURL();
          print('Profile picture uploaded: $profilePictureUrl');
        } catch (storageError) {
          print('Error uploading profile picture: $storageError');
          // Continue with profile creation even if image upload fails
        }
      }

      // Create user model
      final userModel = UserModel(
        id: userId,
        email: email,
        displayName: displayName,
        profilePictureUrl: profilePictureUrl,
        createdAt: DateTime.now(),
      );

      // Convert to map for debugging
      final userMap = userModel.toMap();
      print('Saving user profile: $userMap');

      // Save to Firestore
      await _firestore.collection('users').doc(userId).set(
            userMap,
            SetOptions(merge: true),
          );

      print('User profile saved successfully');

      return userModel;
    } catch (e) {
      print('Error creating/updating user profile: $e');
      rethrow;
    }
  }

  // Email and Password Registration
  Future<UserCredential?> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print('Registration error: ${e.message}');
      return null;
    }
  }

  // Email and Password Login
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print('Login error: ${e.code} - ${e.message}');
      return Future.error(e.message ?? "An unknown error occurred.");
    }
  }

  // Google Sign-In
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // The user canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google user credential
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  // Facebook Sign-In
  Future<UserCredential?> signInWithFacebook() async {
    try {
      // Begin Facebook login flow
      final LoginResult loginResult = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (loginResult.status != LoginStatus.success) {
        print('Facebook login failed: ${loginResult.status}');
        print('Message: ${loginResult.message}');
        return null;
      }

      // Get access token
      final AccessToken? accessToken = loginResult.accessToken;

      if (accessToken == null) {
        print('Facebook access token is null');
        return null;
      }

      // Create Facebook credential
      final OAuthCredential facebookAuthCredential =
          FacebookAuthProvider.credential(accessToken.tokenString);

      // Get user data
      final userData = await FacebookAuth.instance.getUserData();

      // Sign in to Firebase
      final userCredential =
          await _auth.signInWithCredential(facebookAuthCredential);

      // After successful sign in, create/update user profile
      if (userCredential.user != null) {
        await createOrUpdateUserProfile(
          userId: userCredential.user!.uid,
          email: userCredential.user!.email ?? userData['email'] ?? '',
          displayName: userCredential.user!.displayName ?? userData['name'],
          // Add profile picture if available
          profileImage: null, // You can add profile picture handling here
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.message}');
      throw e;
    } catch (e) {
      print('Facebook Sign-In error: $e');
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();

      // Sign out from Google if signed in
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      // Sign out from Facebook if signed in
      final accessToken = await FacebookAuth.instance.accessToken;
      if (accessToken != null) {
        await FacebookAuth.instance.logOut();
      }

      print("User signed out successfully");
    } catch (e) {
      print("Logout error: $e");
    }
  }

  // Error Handling
  void _handleAuthError(FirebaseAuthException e) {
    if (kDebugMode) {
      print('Authentication Error: ${e.code}');
    }

    String errorMessage = 'An unknown error occurred.';
    switch (e.code) {
      case 'weak-password':
        errorMessage = 'The password is too weak.';
        break;
      case 'email-already-in-use':
        errorMessage = 'An account already exists with this email.';
        break;
      case 'invalid-email':
        errorMessage = 'The email address is not valid.';
        break;
      case 'operation-not-allowed':
        errorMessage = 'This operation is not allowed.';
        break;
      case 'user-not-found':
        errorMessage = 'No user found with this email.';
        break;
      case 'wrong-password':
        errorMessage = 'Incorrect password.';
        break;
    }

    throw Exception(errorMessage);
  }
}
