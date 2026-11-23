import '../../../../core/config/supabase_client.dart';
import '../domain/entities/item_search_row.dart';
import '../domain/entities/item.dart';

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
}
