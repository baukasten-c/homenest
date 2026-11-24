import '../../../../core/config/supabase_client.dart';
import '../domain/entities/item_search_row.dart';
import '../domain/entities/item.dart';
import '../domain/entities/item_location.dart';

class ItemRepository {
  /// 按节点 id 列表查物品（来自 v_item_search 视图）。
  /// 排序：临期/过期优先，无到期日的排后面。
  Future<List<ItemSearchRow>> listByNodeIds(List<String> nodeIds) async {
    if (nodeIds.isEmpty) return const [];
    final rows = await supabase
        .from('v_item_search')
        .select()
        .inFilter('space_node_id', nodeIds)
        .gt('quantity', 0)
        .order('expiry_date', ascending: true, nullsFirst: false);
    return rows
        .map((e) => ItemSearchRow.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// 全局模糊搜索（物品搜索页用，可延后接）
  Future<List<ItemSearchRow>> search(String keyword) async {
    final rows = await supabase
        .from('v_item_search')
        .select()
        .ilike('item_name', '%$keyword%')
        .order('expiry_date', ascending: true, nullsFirst: false);
    return rows
        .map((e) => ItemSearchRow.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// 一键消耗（调用 RPC）
  Future<void> consume(String itemId, int qty) async {
    await supabase.rpc(
      'consume_item',
      params: {'p_item_id': itemId, 'p_qty': qty},
    );
  }

  Future<Item?> getById(String id) async {
    final row = await supabase
        .from('items')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Item.fromMap(row);
  }

  Future<Item> create({
    required String familyId,
    required String spaceNodeId,
    required String name,
    String? category,
    required int quantity,
    DateTime? expiryDate,
    DateTime? openedDate,
    int? minQuantity,
    String? note,
  }) async {
    final row = await supabase
        .from('items')
        .insert({
          'family_id': familyId,
          'space_node_id': spaceNodeId,
          'name': name,
          'category': category,
          'quantity': quantity,
          'expiry_date': _dateStr(expiryDate),
          'opened_date': _dateStr(openedDate),
          'min_quantity': minQuantity,
          'note': note,
        })
        .select()
        .single();
    return Item.fromMap(row as Map<String, dynamic>);
  }

  /// 全量更新（表单提交时所有字段一次性传，避免"部分更新漏字段"的坑）
  Future<Item> update({
    required String id,
    required String name,
    String? category,
    required int quantity,
    DateTime? expiryDate,
    DateTime? openedDate,
    int? minQuantity,
    String? note,
  }) async {
    final row = await supabase
        .from('items')
        .update({
          'name': name,
          'category': category,
          'quantity': quantity,
          'expiry_date': _dateStr(expiryDate),
          'opened_date': _dateStr(openedDate),
          'min_quantity': minQuantity,
          'note': note,
        })
        .eq('id', id)
        .select()
        .single();
    return Item.fromMap(row as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await supabase.from('items').delete().eq('id', id);
  }

  /// date 类型字段在 PostgREST 里传 'YYYY-MM-DD' 最稳，不要传 ISO8601 带时区
  String? _dateStr(DateTime? d) {
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────── Marker ───────────────────────────

  Future<ItemLocation?> getMarker({
    required String itemId,
    required String nodeId,
  }) async {
    final row = await supabase
        .from('item_locations')
        .select()
        .eq('item_id', itemId)
        .eq('space_node_id', nodeId)
        .maybeSingle();
    if (row == null) return null;
    return ItemLocation.fromMap(row);
  }

  /// 有则 update 坐标，无则 insert。不覆盖 created_by。
  Future<ItemLocation> upsertMarker({
    required String itemId,
    required String nodeId,
    required double markerX,
    required double markerY,
  }) async {
    final existing = await supabase
        .from('item_locations')
        .select('id')
        .eq('item_id', itemId)
        .eq('space_node_id', nodeId)
        .maybeSingle();

    final Map<String, dynamic> row;
    if (existing == null) {
      row =
          await supabase
                  .from('item_locations')
                  .insert({
                    'item_id': itemId,
                    'space_node_id': nodeId,
                    'marker_x': markerX,
                    'marker_y': markerY,
                    'created_by': supabase.auth.currentUser?.id,
                  })
                  .select()
                  .single()
              as Map<String, dynamic>;
    } else {
      row =
          await supabase
                  .from('item_locations')
                  .update({'marker_x': markerX, 'marker_y': markerY})
                  .eq('id', existing['id'])
                  .select()
                  .single()
              as Map<String, dynamic>;
    }
    return ItemLocation.fromMap(row);
  }

  Future<void> deleteMarker({
    required String itemId,
    required String nodeId,
  }) async {
    await supabase
        .from('item_locations')
        .delete()
        .eq('item_id', itemId)
        .eq('space_node_id', nodeId);
  }

  /// 某节点照片上的所有标记（含物品名/数量），供 2c-2b 用
  Future<List<ItemLocation>> listMarkersByNode(String nodeId) async {
    final rows = await supabase
        .from('item_locations')
        .select('*, items(name, quantity)')
        .eq('space_node_id', nodeId);
    return rows
        .map((e) => ItemLocation.fromMap(e as Map<String, dynamic>))
        .where((loc) => (loc.itemQuantity ?? 0) > 0) // ← 消耗到 0 的物品不显示 marker
        .toList();
  }
}
