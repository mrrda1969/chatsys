import 'package:cloud_firestore/cloud_firestore.dart';

class ContactModel {
  final String id;
  final String userId;
  final String displayName;
  final String email;
  final String? profilePictureUrl;
  final DateTime addedAt;
  final bool isBlocked;

  ContactModel({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.email,
    this.profilePictureUrl,
    DateTime? addedAt,
    this.isBlocked = false,
  }) : addedAt = addedAt ?? DateTime.now();

  factory ContactModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ContactModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      profilePictureUrl: data['profilePictureUrl'],
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isBlocked: data['isBlocked'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'profilePictureUrl': profilePictureUrl,
      'addedAt': addedAt,
      'isBlocked': isBlocked,
    };
  }
}
