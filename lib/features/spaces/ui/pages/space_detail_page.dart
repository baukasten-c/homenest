import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../items/ui/item_viewmodel.dart';
import '../../../items/ui/widgets/item_list_tile.dart';
import '../space_viewmodel.dart';
import '../../../items/domain/entities/item_search_row.dart';
import '../../../items/data/item_repository.dart'; // 如果 consume 用 repo

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
    if (saved == true) {
      ref.invalidate(itemsByNodeProvider(args));
      ref.invalidate(
        itemsByNodeProvider((
          nodeId: widget.nodeId,
          includeDescendants: !_includeDescendants,
        )),
      );
    }
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
}
