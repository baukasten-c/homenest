import '../../../../core/config/supabase_client.dart';
import '../../auth/domain/entities/family_member.dart';
import '../domain/entities/space_node.dart';

class SpaceRepository {
  Future<FamilyMember?> myMembership() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final rows = await supabase
        .from('family_members')
        .select()
        .eq('user_id', uid)
        .limit(1);
    if (rows.isEmpty) return null;
    return FamilyMember.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<List<SpaceNode>> listNodes(String familyId) async {
    final rows = await supabase
        .from('space_nodes')
        .select()
        .eq('family_id', familyId)
        .order('created_at');
    return rows
        .map((e) => SpaceNode.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// 添加子节点。path 的构造规则：和你原代码保持一致，
  /// 如果你原来是在 DB trigger 里维护 path，可以去掉这里的 path 参数。
  Future<SpaceNode> addChild({
    required String familyId,
    required String? parentId,
    required String name,
    String nodeType = 'storage',
    String? path,
  }) async {
    final row = await supabase
        .from('space_nodes')
        .insert({
          'family_id': familyId,
          'parent_id': parentId,
          'name': name,
          'node_type': nodeType,
          if (path != null) 'path': path,
        })
        .select()
        .single();
    return SpaceNode.fromMap(row as Map<String, dynamic>);
  }
}