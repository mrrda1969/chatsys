import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? profilePictureUrl;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.profilePictureUrl,
    this.createdAt,
  });

  // Convert UserModel to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'profilePictureUrl': profilePictureUrl,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  // Create a UserModel from a map (e.g., from Firestore)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      profilePictureUrl: map['profilePictureUrl'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Create a copy of the user with optional updates
  UserModel copyWith({
    String? displayName,
    String? profilePictureUrl,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      createdAt: createdAt,
    );
  }
}
