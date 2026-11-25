-- 把 items 和 item_locations 表加入 Supabase Realtime publication。
-- 幂等写法，重复执行无副作用。

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'items'
  ) then
    alter publication supabase_realtime add table public.items;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'item_locations'
  ) then
    alter publication supabase_realtime add table public.item_locations;
  end if;
end $$;