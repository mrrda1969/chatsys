import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatsys/auth/login_page.dart';
import 'package:chatsys/pages/video_chat_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupCallNotificationListener();
  }

  void _setupCallNotificationListener() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _notificationSubscription = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('notifications')
        .where('status', isEqualTo: 'pending')
        .where('type', isEqualTo: 'call')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final notification = change.doc.data() as Map<String, dynamic>;
              _showIncomingCallDialog(
                notification['callId'],
                notification['callerName'],
              );
            }
          }
        });
  }

  void _showIncomingCallDialog(String callId, String callerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Incoming Video Call'),
          content: Text('$callerName is calling you'),
          actions: [
            TextButton(
              child: const Text('Decline'),
              onPressed: () {
                Navigator.of(context).pop();
                navigateToVideoChat(
                  context,
                  '',
                  callId: callId,
                  isIncomingCall: true,
                  shouldReject: true,
                );
              },
            ),
            ElevatedButton(
              child: const Text('Answer'),
              onPressed: () {
                Navigator.of(context).pop();
                navigateToVideoChat(
                  context,
                  '',
                  callId: callId,
                  isIncomingCall: true,
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Add a user to contacts
  Future<void> _addContact(String userId, String email) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw StateError('No authenticated user');
      }

      // Check if contact already exists
      final existingContact =
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('contacts')
              .doc(userId)
              .get();

      if (existingContact.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$email is already in your contacts'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Add to contacts collection
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('contacts')
          .doc(userId)
          .set({
            'userId': userId,
            'email': email,
            'addedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $email to contacts'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error adding contact: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding contact: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Remove a contact
  Future<void> _removeContact(String userId, String email) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw StateError('No authenticated user');
      }

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('contacts')
          .doc(userId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $email from contacts'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error removing contact: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing contact: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Check if a user is in contacts
  Stream<bool> _isInContacts(String userId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('contacts')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
      }
    } catch (e) {
      print('Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Contacts'), Tab(text: 'Search Users')],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildContactsTab(), _buildSearchTab()],
      ),
    );
  }

  Widget _buildContactsTab() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Center(child: Text('Not logged in'));

    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('contacts')
              .orderBy('addedAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No contacts yet'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final contact = snapshot.data!.docs[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(contact['email'][0].toUpperCase()),
              ),
              title: Text(contact['email']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.video_call),
                    onPressed:
                        () => navigateToVideoChat(context, contact['userId']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed:
                        () =>
                            _removeContact(contact['userId'], contact['email']),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search users',
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                      : null,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('users')
                    .where('email', isGreaterThanOrEqualTo: _searchQuery)
                    .where('email', isLessThan: '${_searchQuery}z')
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final user = snapshot.data!.docs[index];
                  if (user.id == _auth.currentUser?.uid) {
                    return const SizedBox.shrink();
                  }

                  return StreamBuilder<bool>(
                    stream: _isInContacts(user.id),
                    builder: (context, isContactSnapshot) {
                      final isContact = isContactSnapshot.data ?? false;

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(user['email'][0].toUpperCase()),
                        ),
                        title: Text(user['email']),
                        subtitle: Text(
                          isContact ? 'In Contacts' : 'Not in Contacts',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isContact)
                              IconButton(
                                icon: const Icon(Icons.person_remove),
                                onPressed:
                                    () =>
                                        _removeContact(user.id, user['email']),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.person_add),
                                onPressed:
                                    () => _addContact(user.id, user['email']),
                              ),
                            IconButton(
                              icon: const Icon(Icons.video_call),
                              onPressed:
                                  () => navigateToVideoChat(context, user.id),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
