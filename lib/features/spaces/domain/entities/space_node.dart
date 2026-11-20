import '../../../../core/utils/json_utils.dart';

class SpaceNode {
  final String id;
  final String familyId;
  final String? parentId;              // parent_id 可为 null（根节点）
  final String name;
  final String nodeType;               // room / furniture / container / level
  final String? path;

  final String? visualType;
  final double? width;
  final double? height;
  final double? depth;
  final double? positionX;             // ← 新增，之前漏了
  final double? positionY;             // ← 新增
  final double? positionZ;             // ← 新增
  final String? photoUrl;
  final double? markerX;
  final double? markerY;
  final Map<String, dynamic>? modelParams;

  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SpaceNode({
    required this.id,
    required this.familyId,
    this.parentId,
    required this.name,
    required this.nodeType,
    this.path,
    this.visualType,
    this.width,
    this.height,
    this.depth,
    this.positionX,
    this.positionY,
    this.positionZ,
    this.photoUrl,
    this.markerX,
    this.markerY,
    this.modelParams,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory SpaceNode.fromMap(Map<String, dynamic> m) => SpaceNode(
        id: m['id'] as String,
        familyId: m['family_id'] as String,
        parentId: m['parent_id'] as String?,
        name: m['name'] as String,
        nodeType: (m['node_type'] as String?) ?? 'container',
        path: m['path'] as String?,
        visualType: m['visual_type'] as String?,
        width: asDouble(m['width']),
        height: asDouble(m['height']),
        depth: asDouble(m['depth']),
        positionX: asDouble(m['position_x']),
        positionY: asDouble(m['position_y']),
        positionZ: asDouble(m['position_z']),
        photoUrl: m['photo_url'] as String?,
        markerX: asDouble(m['marker_x']),
        markerY: asDouble(m['marker_y']),
        modelParams: m['model_params'] == null
            ? null
            : Map<String, dynamic>.from(m['model_params'] as Map),
        createdBy: m['created_by'] as String?,
        createdAt: asDate(m['created_at']),
        updatedAt: asDate(m['updated_at']),
      );
}