import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final String? profilePicture;
  final String? firebaseUid; // Firebase UID for status
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? phoneNumber;
  final bool isEmailVerified;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.profilePicture,
    this.firebaseUid,
    required this.createdAt,
    required this.updatedAt,
    this.phoneNumber,
    this.isEmailVerified = false,
  });

  // Getter for ID (compatibility with existing code)
  String? get id => uid;

  // Getter for role as string (compatibility with existing code)
  String get roleString => role.name;

  // Getter for profile image (compatibility - use profilePicture)
  String? get profileImage => profilePicture;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role.name,
      'profilePicture': profilePicture,

      'firebaseUid': firebaseUid,
      'phoneNumber': phoneNumber,
      'isEmailVerified': isEmailVerified,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Firestore-specific methods
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'profilePicture': profilePicture,
      'phoneNumber': phoneNumber,
      'isEmailVerified': isEmailVerified,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.student,
      ),
      profilePicture: map['profilePicture'],

      firebaseUid: map['firebaseUid'],
      phoneNumber: map['phoneNumber'],
      isEmailVerified: map['isEmailVerified'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : DateTime.now(),
    );
  }

  // Factory for Firestore documents
  factory UserModel.fromFirestore(String uid, Map<String, dynamic> data) {
    print('🔍 UserModel.fromFirestore: Creating user from data: $data');
    final roleString = data['role'] as String?;
    print('🔍 Role from Firestore: "$roleString"');

    final role = UserRole.values.firstWhere(
      (e) => e.name == roleString,
      orElse: () {
        print(
          '❌ Role not found! Using student as default. Available roles: ${UserRole.values.map((e) => e.name)}',
        );
        return UserRole.student;
      },
    );

    print('🔍 Final role assigned: ${role.name}');

    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: role,
      profilePicture: data['profilePicture'],
      firebaseUid: uid,
      phoneNumber: data['phoneNumber'],
      isEmailVerified: data['isEmailVerified'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    UserRole? role,
    String? profilePicture,
    String? firebaseUid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      profilePicture: profilePicture ?? this.profilePicture,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum UserRole { student, teacher }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Siswa';
      case UserRole.teacher:
        return 'Guru';
    }
  }
}
