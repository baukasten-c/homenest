import 'package:material_ui/material_ui.dart';

import 'core/config/app_router.dart';

class HomeNestApp extends StatelessWidget {
  const HomeNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HomeNest',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      routerConfig: appRouter,
    );
  }
}