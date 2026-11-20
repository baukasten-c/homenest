import '../../../../core/utils/json_utils.dart';

class Item {
  final String id;
  final String familyId;
  final String? spaceNodeId;           // ← on delete set null，可为空
  final String name;
  final String? category;
  final int quantity;
  final DateTime? expiryDate;
  final DateTime? openedDate;
  final int? minQuantity;
  final String? note;
  final double? markerX;               // ← 物品在节点照片上的位置（alter 加的）
  final double? markerY;

  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Item({
    required this.id,
    required this.familyId,
    this.spaceNodeId,
    required this.name,
    this.category,
    required this.quantity,
    this.expiryDate,
    this.openedDate,
    this.minQuantity,
    this.note,
    this.markerX,
    this.markerY,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Item.fromMap(Map<String, dynamic> m) => Item(
        id: m['id'] as String,
        familyId: m['family_id'] as String,
        spaceNodeId: m['space_node_id'] as String?,
        name: m['name'] as String,
        category: m['category'] as String?,
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        expiryDate: asDate(m['expiry_date']),
        openedDate: asDate(m['opened_date']),
        minQuantity: asInt(m['min_quantity']),
        note: m['note'] as String?,
        markerX: asDouble(m['marker_x']),
        markerY: asDouble(m['marker_y']),
        createdBy: m['created_by'] as String?,
        updatedBy: m['updated_by'] as String?,
        createdAt: asDate(m['created_at']),
        updatedAt: asDate(m['updated_at']),
      );
}