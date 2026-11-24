class ItemLocation {
  final String id;
  final String itemId;
  final String spaceNodeId;
  final double markerX;
  final double markerY;
  final String? itemName;      // 来自 join，可能为 null
  final int? itemQuantity;     // 来自 join，可能为 null

  const ItemLocation({
    required this.id,
    required this.itemId,
    required this.spaceNodeId,
    required this.markerX,
    required this.markerY,
    this.itemName,
    this.itemQuantity,
  });

  factory ItemLocation.fromMap(Map<String, dynamic> m) {
    final items = m['items'];
    final itemMap = items is Map ? Map<String, dynamic>.from(items) : null;
    return ItemLocation(
      id: m['id'] as String,
      itemId: m['item_id'] as String,
      spaceNodeId: m['space_node_id'] as String,
      markerX: (m['marker_x'] as num).toDouble(),
      markerY: (m['marker_y'] as num).toDouble(),
      itemName: itemMap?['name'] as String?,
      itemQuantity: (itemMap?['quantity'] as num?)?.toInt(),
    );
  }
}