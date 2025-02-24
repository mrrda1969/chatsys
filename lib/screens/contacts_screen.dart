import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatsys/models/user_model.dart';
import 'package:chatsys/services/auth_service.dart';
import 'package:chatsys/screens/register_page.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  Stream<List<UserModel>> _getUsersStream() {
    return _firestore
        .collection('users')
        .where('id', isNotEqualTo: _auth.currentUser?.uid)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }

  void _signOut() async {
    await _authService.signOut();
    // Navigate back to login screen using direct route
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _getUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No contacts found'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final user = snapshot.data![index];
              return ListTile(
                leading: user.profilePictureUrl != null
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(user.profilePictureUrl!),
                      )
                    : const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                title: Text(user.displayName ?? user.email),
                subtitle: Text(user.email),
                onTap: () {
                  // TODO: Implement chat functionality
                  // Navigator.push(context, MaterialPageRoute(
                  //   builder: (context) => ChatScreen(user: user)
                  // ));
                },
              );
            },
          );
        },
      ),
    );
  }
}
