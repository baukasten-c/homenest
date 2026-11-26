import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:async'; // unawaited

import '../../../../core/config/supabase_client.dart';
import '../../domain/entities/space_node.dart';
import '../space_viewmodel.dart';
import '../../../notifications/ui/notification_service.dart';

class SpaceTreePage extends ConsumerStatefulWidget {
  const SpaceTreePage({super.key});
  @override
  ConsumerState<SpaceTreePage> createState() => _SpaceTreePageState();
}

class _SpaceTreePageState extends ConsumerState<SpaceTreePage> {
  bool _loggingOut = false;
  bool _hasScannedNotifications = false;
  // 原来的 build 和 _buildTreeNodes 等方法搬进来
  @override
  Widget build(BuildContext context) {
    final asyncNodes = ref.watch(nodesProvider);

    // 新增：数据加载成功后，静默触发一次通知扫描
    if (asyncNodes.hasValue && !_hasScannedNotifications) {
      _hasScannedNotifications = true;
      // 放到微任务里，不阻塞当前帧渲染
      Future.microtask(() {
        ref.read(notificationServiceProvider).refreshExpiryNotifications();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HomeNest'),
        actions: [
          IconButton(
            tooltip: '退出登录',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              setState(() => _loggingOut = true);
              try {
                await supabase.auth.signOut();
              } finally {
                if (mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
      body: asyncNodes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (nodes) {
          if (_loggingOut) {
            return const Center(child: CircularProgressIndicator());
          }
          final roots = nodes.where((n) => n.parentId == null).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          if (roots.isEmpty) {
            return const Center(child: Text('还没有空间节点'));
          }
          return ListView(
            children: [
              for (final r in roots)
                ..._buildTreeNodes(context, ref, nodes, r, 0),
            ],
          );
        },
      ),
    );
  }

  /// 对应你原来的 _buildTreeNodes 递归
  List<Widget> _buildTreeNodes(
    BuildContext context,
    WidgetRef ref,
    List<SpaceNode> all,
    SpaceNode node,
    int depth,
  ) {
    final children = all.where((n) => n.parentId == node.id).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return [
      ListTile(
        contentPadding: EdgeInsets.only(left: 16.0 * depth + 16, right: 8),
        leading: Icon(_iconFor(node.nodeType)),
        title: Text(node.name),
        subtitle: node.path != null ? Text(node.path!) : null,
        trailing: IconButton(
          tooltip: '添加子节点',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => _addChildNode(context, ref, node),
        ),
        onTap: () => context.push('/space/${node.id}'),
      ),
      for (final c in children)
        ..._buildTreeNodes(context, ref, all, c, depth + 1),
    ];
  }

  Future<void> _addChildNode(
    BuildContext context,
    WidgetRef ref,
    SpaceNode parent,
  ) async {
    final name = await _promptName(context, parent.name);
    if (name == null || name.trim().isEmpty) return;

    final member = ref.read(myMembershipProvider).value;
    if (member == null) {
      _toast(context, '未找到家庭成员记录');
      return;
    }

    try {
      // TODO(迁移): 如果你原来是用 path = "父.path/name" 拼接，保留；
      // 如果在 DB trigger 里维护，这里传 null 即可
      final path = parent.path != null
          ? '${parent.path}/$name'
          : '${parent.name}/$name';

      await ref
          .read(spaceRepositoryProvider)
          .addChild(
            familyId: member.familyId,
            parentId: parent.id,
            name: name,
            path: path,
          );
      ref.invalidate(nodesProvider); // 自动重新加载，替代 setState 里的 _loadData()
    } catch (e) {
      _toast(context, '添加失败: $e');
    }
  }

  Future<String?> _promptName(BuildContext context, String parentName) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('在「$parentName」下添加子节点'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'room':
        return Icons.meeting_room;
      case 'furniture':
        return Icons.chair;
      case 'container':
        return Icons.inbox;
      default:
        return Icons.folder_outlined;
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
