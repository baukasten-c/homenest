import '../../../../core/utils/json_utils.dart';

/// 对应数据库视图 v_item_search
class ItemSearchRow {
  final String itemId;
  final String familyId;
  final String? spaceNodeId;
  final String itemName;
  final int quantity;
  final DateTime? expiryDate;
  final DateTime? openedDate;
  final String? spaceName;
  final String? spacePath;
  final String? photoUrl;
  final double? markerX;
  final double? markerY;
  final int? daysLeft;

  const ItemSearchRow({
    required this.itemId,
    required this.familyId,
    this.spaceNodeId,
    required this.itemName,
    required this.quantity,
    this.expiryDate,
    this.openedDate,
    this.spaceName,
    this.spacePath,
    this.photoUrl,
    this.markerX,
    this.markerY,
    this.daysLeft,
  });

  factory ItemSearchRow.fromMap(Map<String, dynamic> m) => ItemSearchRow(
        itemId: m['item_id'] as String,
        familyId: m['family_id'] as String,
        spaceNodeId: m['space_node_id'] as String?,
        itemName: m['item_name'] as String,
        quantity: (m['quantity'] as num?)?.toInt() ?? 0,
        expiryDate: asDate(m['expiry_date']),
        openedDate: asDate(m['opened_date']),
        spaceName: m['space_name'] as String?,
        spacePath: m['space_path'] as String?,
        photoUrl: m['photo_url'] as String?,
        markerX: asDouble(m['marker_x']),
        markerY: asDouble(m['marker_y']),
        daysLeft: asInt(m['days_left']),
      );

  bool get isExpiringSoon => daysLeft != null && daysLeft! >= 0 && daysLeft! <= 7;
  bool get isExpired => daysLeft != null && daysLeft! < 0;
}