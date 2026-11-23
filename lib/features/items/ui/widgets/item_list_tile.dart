import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/expiry_badge.dart';
import '../../domain/entities/item_search_row.dart';

class ItemListTile extends StatelessWidget {
  const ItemListTile({
    super.key,
    required this.row,
    this.onTap,
    this.onLongPress,
    this.onConsume,
  });

  final ItemSearchRow row;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onConsume;

  @override
  Widget build(BuildContext context) {
    final canConsume = row.quantity > 0 && onConsume != null;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Text(
          'x${row.quantity}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
      title: Text(row.itemName),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (row.spaceName != null)
              Text(
                row.spaceName!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ExpiryBadge(daysLeft: row.daysLeft),
          ],
        ),
      ),
      trailing: canConsume
          ? IconButton(
              tooltip: '消耗 1（长按整行可指定数量）',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onConsume,
            )
          : null,
    );
  }
}