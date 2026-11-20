import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../space_viewmodel.dart';

class SpaceDetailPage extends ConsumerWidget {
  const SpaceDetailPage({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider).value ?? const [];
    final matches = nodes.where((n) => n.id == nodeId);
    final node = matches.isEmpty ? null : matches.first;

    return Scaffold(
      appBar: AppBar(title: Text(node?.name ?? '节点')),
      body: Center(
        child: Text('物品列表（v_item_search）将在第 2 步实现\nnodeId = $nodeId'),
      ),
    );
  }
}