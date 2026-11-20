import 'package:go_router/go_router.dart';

import '../../features/auth/ui/pages/login_page.dart';
import '../../features/spaces/ui/pages/space_detail_page.dart';
import '../../features/spaces/ui/pages/space_tree_page.dart';
import 'supabase_client.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final loggedIn = supabase.auth.currentUser != null;
    final loc = state.matchedLocation;

    // 启动页分流
    if (loc == '/') return loggedIn ? '/home' : '/login';

    // 未登录访问受保护页面 → 去登录
    if (!loggedIn && loc != '/login') return '/login';

    // 已登录访问登录页 → 回首页
    if (loggedIn && loc == '/login') return '/home';

    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/home', builder: (_, __) => const SpaceTreePage()),
    GoRoute(
      path: '/space/:nodeId',
      builder: (_, state) =>
          SpaceDetailPage(nodeId: state.pathParameters['nodeId']!),
    ),
  ],
);