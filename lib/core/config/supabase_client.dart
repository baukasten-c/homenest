import 'package:supabase_flutter/supabase_flutter.dart';

/// 全局单例访问。所有 repository、页面都从这里拿 client，不要各处直接 import Supabase
SupabaseClient get supabase => Supabase.instance.client;