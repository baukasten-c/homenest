import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../spaces/ui/space_photo_viewmodel.dart';
import '../item_viewmodel.dart';

class ItemMarkerPage extends ConsumerStatefulWidget {
  const ItemMarkerPage({
    super.key,
    required this.nodeId,
    required this.itemId,
  });

  final String nodeId;
  final String itemId;

  @override
  ConsumerState<ItemMarkerPage> createState() => _ItemMarkerPageState();
}

class _ItemMarkerPageState extends ConsumerState<ItemMarkerPage> {
  Offset? _tempMarker;   // 0~1 相对坐标
  bool _loading = true;
  bool _saving = false;
  bool _existing = false;   // 数据库里是否已有标记

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final marker = await ref.read(itemRepositoryProvider).getMarker(
            itemId: widget.itemId,
            nodeId: widget.nodeId,
          );
      if (!mounted) return;
      setState(() {
        if (marker != null) {
          _tempMarker = Offset(marker.markerX, marker.markerY);
          _existing = true;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_tempMarker == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(itemRepositoryProvider).upsertMarker(
            itemId: widget.itemId,
            nodeId: widget.nodeId,
            markerX: _tempMarker!.dx,
            markerY: _tempMarker!.dy,
          );
      ref.invalidate(itemMarkerProvider(
        (itemId: widget.itemId, nodeId: widget.nodeId),
      ));
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('保存失败: $e');
      }
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await ref.read(itemRepositoryProvider).deleteMarker(
            itemId: widget.itemId,
            nodeId: widget.nodeId,
          );
      ref.invalidate(itemMarkerProvider(
        (itemId: widget.itemId, nodeId: widget.nodeId),
      ));
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('删除失败: $e');
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final photoAsync = ref.watch(nodePhotoUrlProvider(widget.nodeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('在照片上标记'),
        actions: [
          if (_existing && !_saving)
            IconButton(
              tooltip: '删除标记',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : photoAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (url) {
                if (url == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '该位置还没有照片。\n请先返回节点详情页上传照片。',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return _buildMarkerCanvas(url);
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => context.pop(false),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: (_tempMarker == null || _saving) ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_existing ? '更新位置' : '保存位置'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarkerCanvas(String url) {
    final aspectAsync = ref.watch(imageAspectRatioProvider(url));

    return aspectAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('图片加载失败')),
      data: (ratio) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AspectRatio(
              aspectRatio: ratio,
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final x = (details.localPosition.dx / constraints.maxWidth)
                          .clamp(0.0, 1.0);
                      final y = (details.localPosition.dy / constraints.maxHeight)
                          .clamp(0.0, 1.0);
                      setState(() => _tempMarker = Offset(x, y));
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(url, fit: BoxFit.fill),
                        if (_tempMarker != null)
                          Positioned(
                            left: _tempMarker!.dx * constraints.maxWidth - 16,
                            top: _tempMarker!.dy * constraints.maxHeight - 16,
                            child: const _MarkerDot(),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
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
      child: const Icon(Icons.star, color: Colors.white, size: 16),
    );
  }
}