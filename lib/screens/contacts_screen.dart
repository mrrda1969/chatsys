import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatsys/models/user_model.dart';
import 'package:chatsys/services/auth_service.dart';
import 'package:chatsys/screens/register_page.dart';
import 'package:chatsys/screens/video_call_screen.dart';

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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  void _initiateVideoCall(UserModel user) async {
    final String callId = _firestore.collection('calls').doc().id;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          callId: callId,
          remoteUserId: user.id,
          isIncoming: false,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _setupCallListener();
  }

  void _setupCallListener() {
    _firestore
        .collection('calls')
        .where('callee', isEqualTo: _auth.currentUser?.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _showIncomingCallDialog(data['caller'], change.doc.id);
        }
      }
    });
  }

  void _showIncomingCallDialog(String callerId, String callId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Incoming Video Call'),
        content: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(callerId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Text('Incoming call...');
            }
            final caller = UserModel.fromMap(
                snapshot.data!.data() as Map<String, dynamic>);
            return Text(
                'Incoming call from ${caller.displayName ?? caller.email}');
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _firestore.collection('calls').doc(callId).update({
                'status': 'rejected',
              });
            },
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoCallScreen(
                    callId: callId,
                    remoteUserId: callerId,
                    isIncoming: true,
                  ),
                ),
              );
            },
            child: const Text('Accept'),
          ),
        ],
      ),
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
                trailing: IconButton(
                  icon: const Icon(Icons.video_call),
                  onPressed: () => _initiateVideoCall(user),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
