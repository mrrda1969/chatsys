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

  // Stream of Firebase User
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

  // Email & Password Sign Up
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
    File? profileImage,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) return null;

      return await createOrUpdateUserProfile(
        userId: userCredential.user!.uid,
        email: email,
        displayName: displayName,
        profileImage: profileImage,
      );
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return null;
    }
  }

  // Email & Password Sign In
  Future<UserCredential?> signInWithEmail(
      {required String email, required String password}) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return null;
    }
  }

  // Google Sign In
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user == null) return null;

      return await createOrUpdateUserProfile(
        userId: userCredential.user!.uid,
        email: userCredential.user!.email!,
        displayName: userCredential.user!.displayName,
      );
    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  // Facebook Sign In
  Future<UserModel?> signInWithFacebook() async {
    try {
      final LoginResult loginResult = await FacebookAuth.instance.login();

      final OAuthCredential facebookAuthCredential =
          FacebookAuthProvider.credential(loginResult.accessToken!.tokenString);

      final userCredential =
          await _auth.signInWithCredential(facebookAuthCredential);

      if (userCredential.user == null) return null;

      return await createOrUpdateUserProfile(
        userId: userCredential.user!.uid,
        email: userCredential.user!.email!,
        displayName: userCredential.user!.displayName,
      );
    } catch (e) {
      print('Facebook Sign-In Error: $e');
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
    await FacebookAuth.instance.logOut();
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
