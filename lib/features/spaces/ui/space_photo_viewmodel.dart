import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/space_photo_repository.dart';
import 'space_viewmodel.dart';
import '../../../../core/utils/image_info.dart';

final spacePhotoRepositoryProvider = Provider<SpacePhotoRepository>((ref) {
  return SpacePhotoRepository();
});

/// 给定节点，返回可展示的签名 URL（null = 无照片）。
/// 依赖 nodesProvider，节点 photo_url 变化后自动刷新。
final nodePhotoUrlProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, nodeId) async {
  final nodes = await ref.watch(nodesProvider.future);
  final matches = nodes.where((n) => n.id == nodeId);
  if (matches.isEmpty) return null;
  final node = matches.first;
  if (node.photoUrl == null || node.photoUrl!.isEmpty) return null;
  return ref.read(spacePhotoRepositoryProvider).signedUrl(node.photoUrl);
});

/// 给定照片 URL，返回宽高比。详情页和标记页共用。
final imageAspectRatioProvider =
    FutureProvider.autoDispose.family<double, String>((ref, url) async {
  return getImageAspectRatio(url);
});