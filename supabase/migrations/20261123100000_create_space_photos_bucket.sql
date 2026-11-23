-- 私有 bucket：家庭空间照片
-- 路径规则：{family_id}/{node_id}.{ext}
-- 访问控制：只有同家庭成员能读写

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'space-photos',
  'space-photos',
  false,
  5242880,  -- 5MB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- ---------- RLS ----------
-- storage.foldername(name)[1] 取路径第一段（family_id）

drop policy if exists "family_read_space_photos" on storage.objects;
create policy "family_read_space_photos"
on storage.objects for select
to authenticated
using (
  bucket_id = 'space-photos'
  and (storage.foldername(name))[1] in (
    select family_id::text from family_members where user_id = auth.uid()
  )
);

drop policy if exists "family_insert_space_photos" on storage.objects;
create policy "family_insert_space_photos"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'space-photos'
  and (storage.foldername(name))[1] in (
    select family_id::text from family_members where user_id = auth.uid()
  )
);

drop policy if exists "family_update_space_photos" on storage.objects;
create policy "family_update_space_photos"
on storage.objects for update
to authenticated
using (
  bucket_id = 'space-photos'
  and (storage.foldername(name))[1] in (
    select family_id::text from family_members where user_id = auth.uid()
  )
);

drop policy if exists "family_delete_space_photos" on storage.objects;
create policy "family_delete_space_photos"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'space-photos'
  and (storage.foldername(name))[1] in (
    select family_id::text from family_members where user_id = auth.uid()
  )
);