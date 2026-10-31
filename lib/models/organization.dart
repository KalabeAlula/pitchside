/// A company or club that arranges its own matches.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    this.about,
    this.subCityId,
    this.subCityName,
    this.createdBy,
    this.createdAt,
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String? about;
  final String? subCityId;
  final String? subCityName;

  /// Only present when the row was fetched whole; embedded selects may omit it.
  final String? createdBy;
  final DateTime? createdAt;

  /// 0 unless the caller counted the roster.
  final int memberCount;

  bool get hasAbout => about != null && about!.trim().isNotEmpty;

  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }

  factory Organization.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'] as String?;
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      about: json['about'] as String?,
      subCityId: json['sub_city_id'] as String?,
      subCityName: json['sub_city_name'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: createdAt == null ? null : DateTime.parse(createdAt),
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Clubs are identified by their primary key, like pitches.
  @override
  bool operator ==(Object other) => other is Organization && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The current user's seat in one club.
class OrganizationMembership {
  const OrganizationMembership({
    required this.organization,
    required this.role,
  });

  final Organization organization;

  /// owner | manager | member
  final String role;

  bool get isOwner => role == 'owner';
  bool get canManage => role == 'owner' || role == 'manager';

  String get roleLabel => switch (role) {
    'owner' => 'Owner',
    'manager' => 'Manager',
    _ => 'Member',
  };

  factory OrganizationMembership.fromJson(Map<String, dynamic> json) {
    final org = json['organizations'];
    return OrganizationMembership(
      organization: Organization.fromJson(
        Map<String, dynamic>.from(org as Map),
      ),
      role: json['role'] as String? ?? 'member',
    );
  }
}

/// One person on a club roster.
class OrganizationMember {
  const OrganizationMember({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final String fullName;
  final String role;
  final DateTime joinedAt;

  bool get canManage => role == 'owner' || role == 'manager';

  String get roleLabel => switch (role) {
    'owner' => 'Owner',
    'manager' => 'Manager',
    _ => 'Member',
  };

  factory OrganizationMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    return OrganizationMember(
      userId: json['user_id'] as String,
      fullName:
          (profile is Map ? profile['full_name'] as String? : null) ?? 'Player',
      role: json['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
