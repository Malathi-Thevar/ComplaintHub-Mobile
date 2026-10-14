import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? uid;
  final String registerNumber;
  final String fullName;
  final String department;
  final String email;
  final String academicYear;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    this.uid,
    required this.registerNumber,
    required this.fullName,
    required this.department,
    required this.email,
    this.academicYear = 'IV Year',
    this.createdAt,
    this.updatedAt,
  });

  UserModel copyWith({
    String? uid,
    String? registerNumber,
    String? fullName,
    String? department,
    String? email,
    String? academicYear,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      registerNumber: registerNumber ?? this.registerNumber,
      fullName: fullName ?? this.fullName,
      department: department ?? this.department,
      email: email ?? this.email,
      academicYear: academicYear ?? this.academicYear,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (uid != null) 'uid': uid,
      'registerNumber': registerNumber,
      'fullName': fullName,
      'department': department,
      'email': email,
      'academicYear': academicYear,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid ?? '',
      'registerNumber': registerNumber,
      'fullName': fullName,
      'department': department,
      'email': email,
      'academicYear': academicYear,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return UserModel(
      uid: map['uid'] as String? ?? docId,
      registerNumber: map['registerNumber'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      department: map['department'] as String? ?? '',
      email: map['email'] as String? ?? '',
      academicYear: map['academicYear'] as String? ?? 'IV Year',
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return UserModel.fromMap(data, snapshot.id);
  }
}
