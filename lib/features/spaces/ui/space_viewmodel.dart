import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/supabase_client.dart';
import '../../auth/domain/entities/family_member.dart';
import '../data/space_repository.dart';
import '../domain/entities/space_node.dart';

final spaceRepositoryProvider = Provider<SpaceRepository>((ref) {
  return SpaceRepository();
});

/// 当前登录用户。监听了 Supabase 的 auth 状态流，
/// 登录 / 登出 / token 刷新都会触发下游 provider 自动失效。
final authUserProvider = StreamProvider<User?>((ref) {
  // 立刻给出当前值，避免首帧等待
  final initial = supabase.auth.currentUser;
  // 监听变化
  final stream = supabase.auth.onAuthStateChange.map(
    (event) => event.session?.user,
  );
  return supabase.auth.onAuthStateChange.map((event) {
    debugPrint(
      '[auth] event=${event.event} email=${event.session?.user.email}',
    );
    return event.session?.user;
  });
});

/// 当前用户的家庭成员记录。
/// 依赖 authUserProvider：切换用户时自动重新查，不会串家庭。
final myMembershipProvider = FutureProvider<FamilyMember?>((ref) async {
  final user = await ref.watch(authUserProvider.future);
  if (user == null) return null;
  return ref.watch(spaceRepositoryProvider).myMembership();
});

/// 当前家庭的所有空间节点。
/// 依赖 myMembershipProvider：familyId 变化时自动重查。
final nodesProvider = FutureProvider<List<SpaceNode>>((ref) async {
  final member = await ref.watch(myMembershipProvider.future);
  if (member == null) return const [];
  return ref.watch(spaceRepositoryProvider).listNodes(member.familyId);
});
