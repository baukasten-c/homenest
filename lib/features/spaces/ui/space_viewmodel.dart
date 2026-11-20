import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/entities/family_member.dart';
import '../data/space_repository.dart';
import '../domain/entities/space_node.dart';

/// 单例 repository（无状态，直接 Provider）
final spaceRepositoryProvider = Provider<SpaceRepository>((ref) {
  return SpaceRepository();
});

/// 当前用户的家庭成员记录（家庭 id 来源）
final myMembershipProvider = FutureProvider<FamilyMember?>((ref) {
  return ref.watch(spaceRepositoryProvider).myMembership();
});

/// 当前家庭所有空间节点。任何地方 ref.invalidate(nodesProvider) 就会重新加载。
final nodesProvider = FutureProvider<List<SpaceNode>>((ref) async {
  final member = await ref.watch(myMembershipProvider.future);
  if (member == null) return const [];
  return ref.watch(spaceRepositoryProvider).listNodes(member.familyId);
});