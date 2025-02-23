import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatsys/auth/login_page.dart'; // Import login page
import 'package:chatsys/pages/video_chat_page.dart'; // Import video chat page

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controller for the add contact dialog
  final TextEditingController _emailController = TextEditingController();

  // Stream to fetch all registered users (except the current user)
  Stream<QuerySnapshot> _getUsersStream() {
    return _firestore
        .collection('users')
        .where('email', isNotEqualTo: _auth.currentUser?.email)
        .snapshots();
  }

  // Stream to fetch user's contacts
  Stream<QuerySnapshot> _getContactsStream() {
    return _firestore
        .collection('users')
        .doc(_auth.currentUser?.uid)
        .collection('contacts')
        .snapshots();
  }

  // Function to add a new contact
  Future<void> _addContact() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    try {
      // Check if the user exists
      final userQuery =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .get();

      if (userQuery.docs.isNotEmpty) {
        // User exists, add to contacts
        await _firestore
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .collection('contacts')
            .doc(userQuery.docs.first.id)
            .set({'email': email, 'addedAt': FieldValue.serverTimestamp()});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact $email added successfully')),
        );
        _emailController.clear();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not found')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding contact: $e')));
    }
  }

  // Show dialog to add a new contact
  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Contact'),
            content: TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                hintText: 'Enter email address',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(onPressed: _addContact, child: const Text('Add')),
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
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(tabs: [Tab(text: 'All Users'), Tab(text: 'My Contacts')]),
            Expanded(
              child: TabBarView(
                children: [
                  // All Users Tab
                  _buildAllUsersTab(),

                  // My Contacts Tab
                  _buildMyContactsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAllUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 100, color: Colors.grey[400]),
                const SizedBox(height: 20),
                Text(
                  'No other users found',
                  style: TextStyle(color: Colors.grey[600], fontSize: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  'Invite friends to join the app!',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var user = snapshot.data!.docs[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  user['email'][0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(user['email'] ?? 'Unknown'),
              subtitle: Text(user['name'] ?? 'No name'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    onPressed: () {
                      _emailController.text = user['email'];
                      _addContact();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.video_call),
                    onPressed: () {
                      // Start video call with this user
                      navigateToVideoChat(context, user.id);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyContactsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getContactsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.contact_page_outlined,
                  size: 100,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 20),
                Text(
                  'No contacts yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  'Add contacts from the "All Users" tab',
                  style: TextStyle(color: Colors.grey[500]),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _showAddContactDialog,
                  child: const Text('Add Contact'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var contact = snapshot.data!.docs[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  contact['email'][0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(contact['email'] ?? 'Unknown'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.message),
                    onPressed: () {
                      // TODO: Implement chat functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chat feature coming soon'),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.video_call),
                    onPressed: () {
                      // Start video call with this contact
                      navigateToVideoChat(context, contact.id);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
