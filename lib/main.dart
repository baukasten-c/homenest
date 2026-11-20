import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

// 如果你原来把 URL/key 硬编码在 main.dart，这里保留原样即可；
// 想更规范可以用 --dart-define=SUPABASE_URL=... 注入
const _supabaseUrl = 'https://aqwtatpxpdlxbqqpfamx.supabase.co';      // ← 填你原来的
const _supabaseAnonKey = 'sb_publishable_PWU0gOBJHa7KE7BYJi8pZA_W84_gTWj';             // ← 填你原来的

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  runApp(const ProviderScope(child: HomeNestApp()));
}
