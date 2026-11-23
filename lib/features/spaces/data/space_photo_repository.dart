import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_client.dart';

class SpacePhotoRepository {
  static const _bucket = 'space-photos';

  /// 上传（覆盖）照片，返回 storage 路径。
  /// 路径：{familyId}/{nodeId}.{ext}
  Future<String> upload({
    required String familyId,
    required String nodeId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final ext = extension.toLowerCase() == 'jpeg' ? 'jpg' : extension.toLowerCase();
    final path = '$familyId/$nodeId.$ext';

    await supabase.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: _contentTypeFor(ext),
      ),
    );

    return path;
  }

  /// 生成临时签名 URL（1 小时有效）。null 输入直接返回 null。
  Future<String?> signedUrl(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return null;
    try {
      return await supabase.storage
          .from(_bucket)
          .createSignedUrl(storagePath, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String storagePath) async {
    await supabase.storage.from(_bucket).remove([storagePath]);
  }

  /// 同步更新 space_nodes.photo_url（存 storage 路径，不是完整 URL）
  Future<void> savePhotoPath({
    required String nodeId,
    required String? storagePath,
  }) async {
    await supabase
        .from('space_nodes')
        .update({'photo_url': storagePath})
        .eq('id', nodeId);
  }

  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}