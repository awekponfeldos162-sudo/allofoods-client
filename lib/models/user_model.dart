// lib/models/user_model.dart

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? imageUrl;
  final String role;
  final String? memberCode;
  final String? fcmToken;
  final String? address;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.imageUrl,
    this.role = 'client',
    this.memberCode,
    this.fcmToken,
    this.address,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      role: map['role'] as String? ?? 'client',
      memberCode: map['memberCode'] as String?,
      fcmToken: map['fcmToken'] as String?,
      address: map['address'] as String?,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is DateTime
              ? map['createdAt'] as DateTime
              : DateTime.tryParse(map['createdAt'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'imageUrl': imageUrl,
      'role': role,
      if (memberCode != null) 'memberCode': memberCode,
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (address != null) 'address': address,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? imageUrl,
    String? role,
    String? memberCode,
    String? fcmToken,
    String? address,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      imageUrl: imageUrl ?? this.imageUrl,
      role: role ?? this.role,
      memberCode: memberCode ?? this.memberCode,
      fcmToken: fcmToken ?? this.fcmToken,
      address: address ?? this.address,
      createdAt: createdAt,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'driver';
  bool get isRestaurantOwner => role == 'restaurant';
  bool get isClient => role == 'client';

  // Compatibilité avec les pages qui utilisent un Map directement
  static UserModel fromProfileData(Map<String, dynamic> data) =>
      UserModel.fromMap(data);
}

// Classe simplifiée pour les formulaires (rétrocompatibilité)
class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String address;

  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    this.address = '',
  });

  factory UserProfile.fromModel(UserModel model) => UserProfile(
        name: model.name,
        email: model.email,
        phone: model.phone,
        address: model.address ?? '',
      );
}
