class FamilyMember {
  final String id;
  final String familyId;
  final String userId;
  final String role;

  const FamilyMember({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
  });

  factory FamilyMember.fromMap(Map<String, dynamic> m) => FamilyMember(
        id: m['id'] as String,
        familyId: m['family_id'] as String,
        userId: m['user_id'] as String,
        role: (m['role'] as String?) ?? 'member',
      );
}