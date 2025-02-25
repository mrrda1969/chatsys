import 'package:chatsys/models/contact_model.dart';
import 'package:chatsys/models/user_model.dart';
import 'package:chatsys/screens/video_call_screen.dart';
import 'package:chatsys/services/auth_service.dart';
import 'package:chatsys/services/contacts_service.dart';
import 'package:chatsys/services/webrtc_service.dart';
import 'package:chatsys/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactsService _contactsService = ContactsService();
  final AuthService _authService = AuthService();
  final WebRTCService _webRTCService = WebRTCService();
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<UserModel> _searchResults = [];
  List<ContactModel> _contacts = [];
  bool _isSearching = false;
  List<Map<String, dynamic>> _incomingCalls = [];
  final Set<String> _processedCallIds = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _listenToIncomingCalls();
  }

  void _loadContacts() {
    _contactsService.getContacts().listen((contacts) {
      setState(() {
        _contacts = contacts;
      });
    });
  }

  void _listenToIncomingCalls() {
    // Listen to incoming calls from Firestore
    _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) async {
      // Fetch caller details for each incoming call
      final incomingCalls = await Future.wait(snapshot.docs
          .where((doc) => !_processedCallIds.contains(doc.id))
          .map((doc) async {
        final callData = doc.data();

        // Fetch caller's details from contacts or user collection
        final callerDoc = await _firestore
            .collection('users')
            .doc(callData['callerId'])
            .get();

        return {
          'id': doc.id,
          'callerId': callData['callerId'],
          'callerName': callerDoc.data()?['displayName'] ??
              callerDoc.data()?['email'] ??
              'Unknown Caller',
        };
      }).toList());

      // Filter out already processed calls
      final newCalls = incomingCalls
          .where((call) => !_processedCallIds.contains(call['id']))
          .toList();

      if (newCalls.isNotEmpty) {
        // Add new call IDs to processed set
        for (var call in newCalls) {
          _processedCallIds.add(call['id']);
        }

        setState(() {
          _incomingCalls = [..._incomingCalls, ...newCalls];
        });

        // Show incoming call dialog for the first new call
        _handleIncomingCall(newCalls.first);
      }
    });
  }

  Future<void> _handleIncomingCall(Map<String, dynamic> call) async {
    try {
      // Check if call is still valid
      final callDoc =
          await _firestore.collection('calls').doc(call['id']).get();
      if (!callDoc.exists || callDoc.data()?['status'] != 'calling') {
        return;
      }

      if (!mounted) return;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildIncomingCallDialog(call),
      );

      if (result ?? false) {
        // Accept call
        await _webRTCService.answerCall(call['id']);
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              contactId: call['callerId'],
              isIncoming: true,
              callId: call['id'],
            ),
          ),
        );
      } else {
        // Reject call
        await _firestore.collection('calls').doc(call['id']).update({
          'status': 'rejected',
          'endedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error handling incoming call: $e');
      _showErrorSnackBar('Error handling incoming call');
    }
  }

  Widget _buildIncomingCallDialog(Map<String, dynamic> call) {
    return AlertDialog(
      title: const Text('Incoming Video Call'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${call['callerName']} is calling...'),
          const SizedBox(height: 8),
          const Text('Would you like to answer?'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Decline'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Answer'),
        ),
      ],
    );
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _contactsService.searchUsers(query);
      if (!mounted) return;

      setState(() {
        _searchResults = results;
        // Filter out existing contacts
        _searchResults.removeWhere(
            (user) => _contacts.any((contact) => contact.userId == user.id));
      });
    } catch (e) {
      print('Error searching users: $e');
      _showErrorSnackBar('Error searching for users');
    }
  }

  void _addContact(UserModel user) async {
    final success = await _contactsService.addContact(user);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('${user.displayName ?? user.email} added to contacts')),
      );
      setState(() {
        _searchResults.remove(user);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add contact')),
      );
    }
  }

  void _removeContact(ContactModel contact) async {
    final success = await _contactsService.removeContact(contact.userId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${contact.displayName} removed from contacts')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove contact')),
      );
    }
  }

  void _blockContact(ContactModel contact) async {
    final success = await _contactsService.blockContact(contact.userId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${contact.displayName} blocked')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to block contact')),
      );
    }
  }

  void _startVideoCall(ContactModel contact) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showErrorSnackBar('Please log in to start a video call');
      return;
    }

    try {
      // Create call document first
      final callDoc = await _firestore.collection('calls').add({
        'callerId': currentUser.uid,
        'callerName': currentUser.displayName ?? currentUser.email,
        'calleeId': contact.userId,
        'calleeName': contact.displayName,
        'status': 'calling',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Start WebRTC call
      final callId = await _webRTCService.startCall(contact.userId);

      if (callId != null) {
        await callDoc.update({'webrtcCallId': callId});

        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              contactId: contact.userId,
              callId: callId,
            ),
          ),
        );
      } else {
        await callDoc.update({'status': 'failed'});
        _showErrorSnackBar('Failed to establish video call');
      }
    } catch (e) {
      print('Error in video call: $e');
      _showErrorSnackBar('Failed to start video call');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _signOut() async {
    await _authService.signOut();
    // Navigate back to login screen using MaterialPageRoute
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Widget _buildAvatar(
      String? imageUrl, String displayName, Color primaryColor) {
    if (imageUrl != null) {
      return CircleAvatar(
        backgroundImage: CachedNetworkImageProvider(imageUrl),
      );
    }
    return CircleAvatar(
      backgroundColor: primaryColor,
      child: Text(
        displayName[0].toUpperCase(),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildContactListTile(ContactModel contact) {
    final theme = Theme.of(context);
    return ListTile(
      leading: _buildAvatar(
          contact.profilePictureUrl, contact.displayName, theme.primaryColor),
      title: Text(contact.displayName),
      subtitle: Text(contact.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video Call Button
          IconButton(
            icon: const Icon(Icons.video_call, color: Colors.green),
            onPressed: () => _startVideoCall(contact),
          ),
          // Existing contact options menu
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'remove':
                  _removeContact(contact);
                  break;
                case 'block':
                  _blockContact(contact);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'remove',
                child: Text('Remove Contact'),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Text('Block Contact'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return Expanded(
      child: _contacts.isEmpty
          ? const Center(child: Text('No contacts found'))
          : ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return _buildContactListTile(contact);
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          // Profile Button with Logout Option
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchUsers('');
                        },
                      )
                    : null,
              ),
              onChanged: _searchUsers,
            ),
          ),

          // Search Results
          if (_isSearching)
            Expanded(
              child: _searchResults.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          leading: _buildAvatar(
                              user.profilePictureUrl,
                              user.displayName ?? user.email,
                              theme.primaryColor),
                          title: Text(user.displayName ?? user.email),
                          subtitle: Text(user.email),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => _addContact(user),
                          ),
                        );
                      },
                    ),
            ),

          // Contacts List
          if (!_isSearching) _buildContactsList(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Cancel any subscriptions if needed
    super.dispose();
  }
}
