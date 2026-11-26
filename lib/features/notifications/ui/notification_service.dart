import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_client.dart';
import '../../items/ui/item_viewmodel.dart';
import '../../spaces/ui/space_viewmodel.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

class NotificationService {
  final NotificationRepository _repo;
  final Ref _ref;

  NotificationService(this._repo, this._ref);

  /// 扫描临期物品并调度通知
  Future<void> refreshExpiryNotifications() async {
    if (kIsWeb) return;

    // 1. 确保初始化和权限
    await _repo.init();
    final hasPermission = await _repo.requestPermissions();
    if (!hasPermission) return;

    // 2. 获取当前家庭
    final member = await _ref.read(myMembershipProvider.future);
    if (member == null) return;

    // 3. 查询 0~3 天内过期的物品
    final today = DateTime.now();
    final threeDaysLater = today.add(const Duration(days: 3));
    
    // 注意：这里直接查 v_item_search，不用 provider，避免依赖 UI 状态
    final rows = await supabase
        .from('v_item_search')
        .select('item_name, days_left')
        .eq('family_id', member.familyId)
        .gte('days_left', 0)
        .lte('days_left', 3)
        .order('days_left');

    // 4. 组装并调度
    if (rows.isEmpty) {
      await _repo.cancelAll();
      return;
    }

    final itemNames = rows.map((e) => e['item_name'] as String).toList();
    final count = itemNames.length;
    
    // 最多列出前 3 个，防止内容过长
    final previewList = itemNames.take(3).join('、');
    final suffix = count > 3 ? ' 等' : '';
    final title = '$count 件物品即将过期';
    final body = '$previewList$suffix将在 3 天内过期，记得处理哦。';
    final testTime = DateTime.now().add(const Duration(minutes: 2));

    // 每天早上 8:00 提醒
    await _repo.scheduleExpiryNotification(
      title: title,
      body: body,
      //hour: 8,
      //minute: 0,
      hour: testTime.hour,     // 用当前小时
      minute: testTime.minute,
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(notificationRepositoryProvider), ref);
});