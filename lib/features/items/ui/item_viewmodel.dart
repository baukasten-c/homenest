import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../spaces/ui/space_viewmodel.dart';
import '../data/item_repository.dart';
import '../domain/entities/item_search_row.dart';

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository();
});

/// 按节点查物品。args.includeDescendants = true 时包含所有子孙节点。
///
/// 实现思路：不依赖 path 格式匹配，而是直接复用 nodesProvider 的全部节点，
/// 在 Dart 层递归收集后代 id，然后一次性 inFilter 查视图。
/// 好处：path 规则怎么变都不影响查询；坏处：家族节点很多时内存里遍历一遍（现阶段可忽略）。
final itemsByNodeProvider = FutureProvider.autoDispose
    .family<List<ItemSearchRow>, ({String nodeId, bool includeDescendants})>(
        (ref, args) async {
  final allNodes = await ref.watch(nodesProvider.future);

  final targetList = allNodes.where((n) => n.id == args.nodeId).toList();
  if (targetList.isEmpty) return const [];
  final targetNode = targetList.first;

  final nodeIds = <String>{targetNode.id};
  if (args.includeDescendants) {
    void collect(String parentId) {
      for (final n in allNodes) {
        if (n.parentId == parentId) {
          nodeIds.add(n.id);
          collect(n.id);
        }
      }
    }

    collect(targetNode.id);
  }

  return ref.read(itemRepositoryProvider).listByNodeIds(nodeIds.toList());
});