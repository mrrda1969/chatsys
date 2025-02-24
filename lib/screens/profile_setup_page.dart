import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatsys/models/user_model.dart';
import 'package:chatsys/services/auth_service.dart';
import 'package:chatsys/screens/contacts_screen.dart';

class ProfileSetupPage extends StatefulWidget {
  final UserModel initialUser;

  const ProfileSetupPage({super.key, required this.initialUser});

  @override
  _ProfileSetupPageState createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final AuthService _authService = AuthService();
  final TextEditingController _displayNameController = TextEditingController();
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Pre-fill display name if available
    _displayNameController.text = widget.initialUser.displayName ?? '';
  }

  Future<void> _pickProfileImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    try {
      // Validate display name
      if (_displayNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a display name')),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Update user profile
      final updatedUser = await _authService.createOrUpdateUserProfile(
        userId: widget.initialUser.id,
        email: widget.initialUser.email,
        displayName: _displayNameController.text.trim(),
        profileImage: _profileImage,
      );

      // Dismiss loading indicator
      Navigator.of(context).pop();

      // Navigate to contacts screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ContactsScreen()),
      );
    } catch (e) {
      // Dismiss loading indicator if still showing
      Navigator.of(context, rootNavigator: true).pop();

      // Show detailed error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture Selection
            GestureDetector(
              onTap: _pickProfileImage,
              child: CircleAvatar(
                radius: 80,
                backgroundColor: Colors.grey[200],
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!) as ImageProvider<Object>?
                    : (widget.initialUser.profilePictureUrl != null
                        ? NetworkImage(widget.initialUser.profilePictureUrl!)
                            as ImageProvider<Object>?
                        : null),
                child: _profileImage == null &&
                        widget.initialUser.profilePictureUrl == null
                    ? const Icon(Icons.camera_alt, size: 50)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to ${_profileImage == null ? 'add' : 'change'} profile picture',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),

            // Display Name Input
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 32),

            // Save Profile Button
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }
}
