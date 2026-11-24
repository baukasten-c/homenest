import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../spaces/ui/space_viewmodel.dart';
import '../../domain/entities/item.dart';
import '../item_viewmodel.dart';

class ItemFormPage extends ConsumerStatefulWidget {
  const ItemFormPage({super.key, required this.nodeId, this.itemId});

  final String nodeId;
  final String? itemId;

  bool get isEditing => itemId != null;

  @override
  ConsumerState<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends ConsumerState<ItemFormPage> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _minQuantityController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _expiryDate;
  DateTime? _openedDate;

  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loading = true;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    try {
      final item = await ref
          .read(itemRepositoryProvider)
          .getById(widget.itemId!);
      if (!mounted) return;
      if (item == null) {
        _toast('物品不存在');
        context.pop();
        return;
      }
      _nameController.text = item.name;
      _categoryController.text = item.category ?? '';
      _quantityController.text = item.quantity.toString();
      _minQuantityController.text = item.minQuantity?.toString() ?? '';
      _noteController.text = item.note ?? '';
      setState(() {
        _expiryDate = item.expiryDate;
        _openedDate = item.openedDate;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _minQuantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return _toast('名称不能为空');

    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity < 0) return _toast('数量必须是 ≥0 的整数');

    final minQuantity = _minQuantityController.text.trim().isEmpty
        ? null
        : int.tryParse(_minQuantityController.text.trim());
    if (_minQuantityController.text.trim().isNotEmpty && minQuantity == null) {
      return _toast('最低数量格式不正确');
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(itemRepositoryProvider);
      if (widget.isEditing) {
        await repo.update(
          id: widget.itemId!,
          name: name,
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          quantity: quantity,
          expiryDate: _expiryDate,
          openedDate: _openedDate,
          minQuantity: minQuantity,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      } else {
        final member = ref.read(myMembershipProvider).value;
        if (member == null) {
          setState(() => _saving = false);
          return _toast('未找到家庭成员记录');
        }
        await repo.create(
          familyId: member.familyId,
          spaceNodeId: widget.nodeId,
          name: name,
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          quantity: quantity,
          expiryDate: _expiryDate,
          openedDate: _openedDate,
          minQuantity: minQuantity,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      }
      ref.invalidate(itemsByNodeProvider);
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除物品'),
        content: Text('确定删除「${_nameController.text}」吗？'),
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

    setState(() => _saving = true);
    try {
      await ref.read(itemRepositoryProvider).delete(widget.itemId!);
      ref.invalidate(itemsByNodeProvider);
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
      }
    }
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) onPicked(picked);
  }

  String _fmt(DateTime? d) {
    if (d == null) return '未设置';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑物品' : '添加物品'),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.isEditing) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('在照片上标记位置'),
                      subtitle: const Text('在当前节点的实景照片上点选物品位置'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openMarkerPage,
                    ),
                  ),
                ],
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '名称 *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '数量 *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _minQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '最低数量',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('到期日'),
                  subtitle: Text(_fmt(_expiryDate)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_expiryDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _expiryDate = null),
                        ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _pickDate(
                          current: _expiryDate,
                          onPicked: (d) => setState(() => _expiryDate = d),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('开封日'),
                  subtitle: Text(_fmt(_openedDate)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_openedDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _openedDate = null),
                        ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _pickDate(
                          current: _openedDate,
                          onPicked: (d) => setState(() => _openedDate = d),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.isEditing ? '保存' : '添加'),
                ),
              ],
            ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openMarkerPage() async {
    final saved = await context.push<bool>(
      '/space/${widget.nodeId}/item/${widget.itemId}/mark',
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('标记已更新')));
    }
  }
}
