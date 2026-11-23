-- 物品在多个位置的多对多标记
-- 物品的"主位置"仍由 items.space_node_id 表达；
-- item_locations 记录"物品出现在哪些照片的哪个位置"。
-- 每个 (item, node) 组合最多一个标记（唯一约束）。

create table if not exists item_locations (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references items(id) on delete cascade,
  space_node_id uuid not null references space_nodes(id) on delete cascade,
  marker_x numeric not null check (marker_x >= 0 and marker_x <= 1),
  marker_y numeric not null check (marker_y >= 0 and marker_y <= 1),
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  unique (item_id, space_node_id)
);

create index if not exists idx_item_locations_item on item_locations(item_id);
create index if not exists idx_item_locations_node on item_locations(space_node_id);

alter table item_locations enable row level security;

-- 读写前提：item 属于当前用户所在家庭，且 item 与 node 属于同一家庭
drop policy if exists "item_locations_select" on item_locations;
create policy "item_locations_select"
on item_locations for select
to authenticated
using (
  exists (
    select 1 from items i
    join space_nodes s on s.id = space_node_id
    join family_members fm on fm.family_id = i.family_id
    where i.id = item_id
      and s.family_id = i.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "item_locations_insert" on item_locations;
create policy "item_locations_insert"
on item_locations for insert
to authenticated
with check (
  exists (
    select 1 from items i
    join space_nodes s on s.id = space_node_id
    join family_members fm on fm.family_id = i.family_id
    where i.id = item_id
      and s.family_id = i.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "item_locations_update" on item_locations;
create policy "item_locations_update"
on item_locations for update
to authenticated
using (
  exists (
    select 1 from items i
    join space_nodes s on s.id = space_node_id
    join family_members fm on fm.family_id = i.family_id
    where i.id = item_id
      and s.family_id = i.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "item_locations_delete" on item_locations;
create policy "item_locations_delete"
on item_locations for delete
to authenticated
using (
  exists (
    select 1 from items i
    join space_nodes s on s.id = space_node_id
    join family_members fm on fm.family_id = i.family_id
    where i.id = item_id
      and s.family_id = i.family_id
      and fm.user_id = auth.uid()
  )
);

grant select, insert, update, delete on item_locations to authenticated;