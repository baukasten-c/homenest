import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_client.dart';
import '../../spaces/ui/space_viewmodel.dart';
import '../data/item_repository.dart';
import '../domain/entities/item_location.dart';
import '../domain/entities/item_search_row.dart';

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository();
});

// ───────────────── items 列表（含 Realtime） ─────────────────

final itemsByNodeProvider = FutureProvider.autoDispose
    .family<List<ItemSearchRow>, ({String nodeId, bool includeDescendants})>(
        (ref, args) async {
  final member = await ref.watch(myMembershipProvider.future);
  final allNodes = await ref.watch(nodesProvider.future);

  if (member == null) return const [];
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

  // 订阅 items 表（filter family_id）——任何变更都触发重查
  final chName =
      'items-${args.nodeId}-${args.includeDescendants}-${DateTime.now().microsecondsSinceEpoch}';
  final channel = supabase.channel(chName);
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'items',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'family_id',
      value: member.familyId,
    ),
    callback: (_) => ref.invalidateSelf(),
  );
  channel.subscribe((status, error) {
    if (status == RealtimeSubscribeStatus.channelError) {
      debugPrint('[Realtime] items channel error: $error');
    } else if (status == RealtimeSubscribeStatus.subscribed) {
      debugPrint('[Realtime] subscribed: $chName');
    }
  });
  ref.onDispose(() => supabase.removeChannel(channel));

  return ref.read(itemRepositoryProvider).listByNodeIds(nodeIds.toList());
});

// ─────────────── 单个物品的 marker（单查，不订阅） ───────────────

final itemMarkerProvider = FutureProvider.autoDispose
    .family<ItemLocation?, ({String itemId, String nodeId})>((ref, args) {
  return ref.read(itemRepositoryProvider).getMarker(
        itemId: args.itemId,
        nodeId: args.nodeId,
      );
});

// ───────── 节点上所有 marker（订阅 item_locations + items） ─────────

final nodeMarkersProvider = FutureProvider.autoDispose
    .family<List<ItemLocation>, String>((ref, nodeId) async {
  final member = await ref.watch(myMembershipProvider.future);
  if (member == null) return const [];

  // 订阅 1：item_locations 表（marker 的增删改）
  final chNameLoc =
      'markers-loc-$nodeId-${DateTime.now().microsecondsSinceEpoch}';
  final chLoc = supabase.channel(chNameLoc);
  chLoc.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'item_locations',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'space_node_id',
      value: nodeId,
    ),
    callback: (_) => ref.invalidateSelf(),
  );
  chLoc.subscribe((status, error) {
    if (status == RealtimeSubscribeStatus.channelError) {
      debugPrint('[Realtime] markers-loc channel error: $error');
    } else if (status == RealtimeSubscribeStatus.subscribed) {
      debugPrint('[Realtime] subscribed: $chNameLoc');
    }
  });
  ref.onDispose(() => supabase.removeChannel(chLoc));

  // 订阅 2：items 表（数量/名称变化影响 marker 上的数字；删除物品时对应 marker 应消失）
  final chNameItems =
      'markers-items-$nodeId-${DateTime.now().microsecondsSinceEpoch}';
  final chItems = supabase.channel(chNameItems);
  chItems.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'items',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'family_id',
      value: member.familyId,
    ),
    callback: (_) => ref.invalidateSelf(),
  );
  chItems.subscribe((status, error) {
    if (status == RealtimeSubscribeStatus.channelError) {
      debugPrint('[Realtime] markers-items channel error: $error');
    }
  });
  ref.onDispose(() => supabase.removeChannel(chItems));

  return ref.read(itemRepositoryProvider).listMarkersByNode(nodeId);
});