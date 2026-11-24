import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/supabase_client.dart';
import '../../../items/domain/entities/item_search_row.dart';
import '../../../items/ui/item_viewmodel.dart';
import '../../../items/ui/widgets/item_list_tile.dart';
import '../space_photo_viewmodel.dart';
import '../space_viewmodel.dart';
import '../../../items/domain/entities/item_location.dart';

class SpaceDetailPage extends ConsumerStatefulWidget {
  const SpaceDetailPage({super.key, required this.nodeId});

  final String nodeId;

  @override
  ConsumerState<SpaceDetailPage> createState() => _SpaceDetailPageState();
}

class _SpaceDetailPageState extends ConsumerState<SpaceDetailPage> {
  bool _includeDescendants = false;

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider).value ?? const [];
    final nodeMatches = nodes.where((n) => n.id == widget.nodeId).toList();
    final node = nodeMatches.isEmpty ? null : nodeMatches.first;

    final args = (
      nodeId: widget.nodeId,
      includeDescendants: _includeDescendants,
    );
    final asyncItems = ref.watch(itemsByNodeProvider(args));

    return Scaffold(
      appBar: AppBar(title: Text(node?.name ?? '节点')),
      body: Column(
        children: [
          _buildPhotoSection(context, ref),
          if (node?.path != null && node!.path!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                node.path!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          SwitchListTile(
            title: const Text('包含子节点物品'),
            value: _includeDescendants,
            onChanged: (v) => setState(() => _includeDescendants = v),
          ),
          const Divider(height: 1),
          Expanded(
            child: asyncItems.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('这个位置还没有物品'));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(itemsByNodeProvider(args));
                    await ref.read(itemsByNodeProvider(args).future);
                  },
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final row = items[i];
                      return ItemListTile(
                        row: row,
                        onTap: () => _openEditItemForm(row.itemId),
                        onLongPress: () => _consume(row), // 长按整行 → 弹框
                        onConsume: () => _consume(row, qty: 1), // 点 - → 直接消耗 1
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewItemForm,
        tooltip: '添加物品',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openNewItemForm() async {
    final args = (
      nodeId: widget.nodeId,
      includeDescendants: _includeDescendants,
    );
    final saved = await context.push<bool>('/space/${widget.nodeId}/item/new');
    if (saved == true) {
      ref.invalidate(itemsByNodeProvider(args));
      // 保险起见，也把另一个 args 的缓存清掉（用户可能切过开关）
      ref.invalidate(
        itemsByNodeProvider((
          nodeId: widget.nodeId,
          includeDescendants: !_includeDescendants,
        )),
      );
    }
  }

  Future<void> _openEditItemForm(String itemId) async {
    final args = (
      nodeId: widget.nodeId,
      includeDescendants: _includeDescendants,
    );
    final saved = await context.push<bool>(
      '/space/${widget.nodeId}/item/$itemId/edit',
    );

    // 物品字段可能改了：只有 saved==true 才刷新列表
    if (saved == true) {
      ref.invalidate(itemsByNodeProvider(args));
      ref.invalidate(
        itemsByNodeProvider((
          nodeId: widget.nodeId,
          includeDescendants: !_includeDescendants,
        )),
      );
    }

    // 标记位置可能改了：无论是否保存都刷新（用户可能只动了 marker 就返回）
    ref.invalidate(nodeMarkersProvider(widget.nodeId));
  }

  Future<void> _consume(ItemSearchRow row, {int? qty}) async {
    if (row.quantity <= 0) return;

    final n = qty ?? await _promptConsumeQty(row);
    if (n == null || n <= 0) return;

    try {
      await ref.read(itemRepositoryProvider).consume(row.itemId, n);
      ref.invalidate(
        itemsByNodeProvider((
          nodeId: widget.nodeId,
          includeDescendants: _includeDescendants,
        )),
      );
      ref.invalidate(
        itemsByNodeProvider((
          nodeId: widget.nodeId,
          includeDescendants: !_includeDescendants,
        )),
      );
      ref.invalidate(nodeMarkersProvider(widget.nodeId));
      if (!mounted) return;
      final left = row.quantity - n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            left <= 0
                ? '已用完「${row.itemName}」'
                : '已消耗 $n「${row.itemName}」，剩余 $left',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('消耗失败: $e')));
    }
  }

  Future<int?> _promptConsumeQty(ItemSearchRow row) async {
    final controller = TextEditingController(text: '1');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('消耗「${row.itemName}」'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前数量：${row.quantity}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '消耗数量',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n == null || n <= 0 || n > row.quantity) return;
              Navigator.pop(ctx, n);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return result;
  }

  Widget _buildPhotoSection(BuildContext context, WidgetRef ref) {
    final photoAsync = ref.watch(nodePhotoUrlProvider(widget.nodeId));
    final markers =
        ref.watch(nodeMarkersProvider(widget.nodeId)).value ?? const [];

    return photoAsync.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _photoPlaceholder(ref, '照片加载失败'),
      data: (url) {
        if (url == null) {
          return _photoPlaceholder(ref, null);
        }
        final maxH = MediaQuery.of(context).size.height * 0.35;
        final aspectAsync = ref.watch(imageAspectRatioProvider(url));
        return aspectAsync.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => _photoPlaceholder(ref, '照片加载失败'),
          data: (ratio) => Stack(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxH,
                  maxWidth: double.infinity,
                ),
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            url,
                            key: ValueKey(url),
                            fit: BoxFit.fill,
                            errorBuilder: (_, __, ___) =>
                                _photoPlaceholder(ref, '图片损坏'),
                          ),
                          // 叠加每个 marker
                          for (final m in markers) _buildMarker(m, w, h),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'change') {
                      await _pickAndUploadPhoto(ref);
                    } else if (v == 'delete') {
                      await _deletePhoto(ref);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'change', child: Text('更换照片')),
                    PopupMenuItem(value: 'delete', child: Text('删除照片')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarker(ItemLocation m, double containerW, double containerH) {
    const size = 32.0;
    final left = (m.markerX * containerW) - (size / 2);
    final top = (m.markerY * containerH) - (size / 2);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _openEditItemForm(m.itemId),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${m.itemQuantity ?? ''}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder(WidgetRef ref, String? message) {
    return Container(
      height: 160,
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message != null) ...[
              Text(message, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: () => _pickAndUploadPhoto(ref),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('上传照片'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // Web 必须为 true，字节数据才在 files[0].bytes 里
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _toast('无法读取文件');
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      _toast('照片不能超过 5MB');
      return;
    }

    final member = ref.read(myMembershipProvider).value;
    if (member == null) {
      _toast('未找到家庭成员记录');
      return;
    }

    final ext = (file.extension ?? 'jpg').toLowerCase();

    try {
      final repo = ref.read(spacePhotoRepositoryProvider);

      // 如果已有旧照片，先尝试删除旧路径（失败不阻塞）
      final nodes = ref.read(nodesProvider).value ?? const [];
      final currentNode = nodes.where((n) => n.id == widget.nodeId);
      final oldPath = currentNode.isEmpty ? null : currentNode.first.photoUrl;
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          await repo.delete(oldPath);
        } catch (_) {
          /* ignore */
        }
      }

      final path = await repo.upload(
        familyId: member.familyId,
        nodeId: widget.nodeId,
        bytes: bytes,
        extension: ext,
      );
      await repo.savePhotoPath(nodeId: widget.nodeId, storagePath: path);

      ref.invalidate(nodesProvider);
      // nodePhotoUrlProvider 依赖 nodesProvider，会自动失效重取
    } catch (e) {
      _toast('上传失败: $e');
    }
  }

  Future<void> _deletePhoto(WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除照片'),
        content: const Text('确定删除当前节点的照片吗？物品列表不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final nodes = ref.read(nodesProvider).value ?? const [];
    final matches = nodes.where((n) => n.id == widget.nodeId);
    if (matches.isEmpty) return;
    final path = matches.first.photoUrl;
    if (path == null) return;

    try {
      final repo = ref.read(spacePhotoRepositoryProvider);
      try {
        await repo.delete(path);
      } catch (_) {
        /* 文件可能已不存在，忽略 */
      }
      await repo.savePhotoPath(nodeId: widget.nodeId, storagePath: null);
      ref.invalidate(nodesProvider);
      _toast('已删除照片');
    } catch (e) {
      _toast('删除失败: $e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
