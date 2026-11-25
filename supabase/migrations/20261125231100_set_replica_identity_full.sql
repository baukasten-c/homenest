-- 允许 Realtime 在 DELETE 事件中携带完整旧行数据，使过滤器生效。
-- 这是 Supabase 对 DELETE 事件过滤的官方解决方案。

alter table public.items replica identity full;
alter table public.item_locations replica identity full;