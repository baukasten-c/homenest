import 'package:material_ui/material_ui.dart';

class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.daysLeft});

  final int? daysLeft;

  @override
  Widget build(BuildContext context) {
    if (daysLeft == null) return const SizedBox.shrink();
    final d = daysLeft!;

    final Color bg;
    final Color fg;
    final String text;

    if (d < 0) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
      text = '已过期 ${-d} 天';
    } else if (d == 0) {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade700;
      text = '今天过期';
    } else if (d <= 7) {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade700;
      text = '$d 天后过期';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12)),
    );
  }
}