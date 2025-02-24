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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    try {
      _tabController.dispose();
      _searchController.dispose();
    } catch (e) {
      print('Error during contacts page disposal: $e');
    } finally {
      super.dispose();
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$email is already in your contacts'),
            backgroundColor: Colors.orange,
          ),
        );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $email to contacts'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error adding contact: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding contact: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $email from contacts'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error removing contact: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing contact: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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

  // Logout method with better error handling and safe navigation
  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      // Use a post-frame callback to ensure the context is still valid
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      });
    } catch (e) {
      print('Logout error: $e');

      // Use post-frame callback for error display
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  // Enhanced navigation to video chat with error handling
  void _safeNavigateToVideoChat(BuildContext context, String userId) {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to start a video call')),
        );
        return;
      }

      // Use a try-catch block for navigation
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => VideoChatPage(peerId: userId, isIncomingCall: false),
        ),
      );
    } catch (e) {
      print('Navigation error in contacts page: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start video call: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
        children: [
          // Contacts Tab
          _buildContactsTab(),

          // Search Users Tab
          _buildSearchTab(),
        ],
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Error loading contacts',
                  style: TextStyle(color: Colors.red[700], fontSize: 18),
                ),
                Text(
                  'Details: ${snapshot.error}',
                  style: TextStyle(color: Colors.red[400]),
                ),
                TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No contacts yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add contacts using the search tab',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final contact = snapshot.data!.docs[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  contact['email'][0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(contact['email']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.video_call),
                    onPressed:
                        () => _safeNavigateToVideoChat(
                          context,
                          contact['userId'],
                        ),
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
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users by email',
              prefixIcon: const Icon(Icons.search),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        // Search Results with more robust error handling
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading search results',
                        style: TextStyle(color: Colors.red[700], fontSize: 18),
                      ),
                      Text(
                        'Details: ${snapshot.error}',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                      TextButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final user = snapshot.data!.docs[index];
                  // Don't show current user in search results
                  if (user.id == _auth.currentUser?.uid)
                    return const SizedBox.shrink();

                  return StreamBuilder<bool>(
                    stream: _isInContacts(user.id),
                    builder: (context, isContactSnapshot) {
                      final isContact = isContactSnapshot.data ?? false;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            user['email'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
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
                                  () => _safeNavigateToVideoChat(
                                    context,
                                    user.id,
                                  ),
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
