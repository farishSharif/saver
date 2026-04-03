class UserProfile {
  final String id;
  final String role;
  final String? fullName;
  final String? inviteCode;
  final String? adminId;

  UserProfile({
    required this.id,
    required this.role,
    this.fullName,
    this.inviteCode,
    this.adminId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      role: json['role'] as String,
      fullName: json['full_name'] as String?,
      inviteCode: json['invite_code'] as String?,
      adminId: json['admin_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'full_name': fullName,
      'invite_code': inviteCode,
      'admin_id': adminId,
    };
  }
}
