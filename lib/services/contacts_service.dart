import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/contact_model.dart';
import '../models/user_model.dart';

class ContactsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Search for users by email or display name
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      // Current user should not be included in search results
      final currentUserId = _auth.currentUser?.uid;

      // Search by email or display name
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('email', isLessThan: '${query.toLowerCase()}\uf8ff')
          .get();

      // Convert to UserModel and filter out current user
      return querySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((user) => user.id != currentUserId)
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Add a contact
  Future<bool> addContact(UserModel user) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return false;

      // Reference to current user's contacts collection
      final contactsRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('contacts');

      // Create contact model
      final contactModel = ContactModel(
        id: user.id,
        userId: user.id,
        displayName: user.displayName ?? user.email,
        email: user.email,
        profilePictureUrl: user.profilePictureUrl,
      );

      // Add to contacts
      await contactsRef.doc(user.id).set(contactModel.toMap());

      return true;
    } catch (e) {
      print('Error adding contact: $e');
      return false;
    }
  }

  // Get user's contacts
  Stream<List<ContactModel>> getContacts() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('contacts')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContactModel.fromFirestore(doc))
            .toList());
  }

  // Remove a contact
  Future<bool> removeContact(String contactId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return false;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('contacts')
          .doc(contactId)
          .delete();

      return true;
    } catch (e) {
      print('Error removing contact: $e');
      return false;
    }
  }

  // Block a contact
  Future<bool> blockContact(String contactId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return false;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('contacts')
          .doc(contactId)
          .update({'isBlocked': true});

      return true;
    } catch (e) {
      print('Error blocking contact: $e');
      return false;
    }
  }
}
