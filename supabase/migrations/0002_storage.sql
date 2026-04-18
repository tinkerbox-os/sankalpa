-- Sankalpa — Phase 1 Storage buckets
--
-- Creates the three Storage buckets used by the app and applies owner-only
-- RLS policies so each user can only read/write objects under their own
-- `<user_id>/...` prefix.

----------------------------------------------------------------------
-- Buckets
----------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('manifestation-images', 'manifestation-images', false),
  ('voice-recordings',     'voice-recordings',     false),
  ('user-sounds',          'user-sounds',          false)
on conflict (id) do nothing;

----------------------------------------------------------------------
-- Policies
----------------------------------------------------------------------
-- Object key convention: `<auth.uid()>/<filename>`. The first path segment
-- determines ownership.

drop policy if exists "sankalpa storage owner can read"   on storage.objects;
drop policy if exists "sankalpa storage owner can write"  on storage.objects;

create policy "sankalpa storage owner can read"
  on storage.objects for select
  using (
    bucket_id in ('manifestation-images', 'voice-recordings', 'user-sounds')
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "sankalpa storage owner can write"
  on storage.objects for all
  using (
    bucket_id in ('manifestation-images', 'voice-recordings', 'user-sounds')
    and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id in ('manifestation-images', 'voice-recordings', 'user-sounds')
    and auth.uid()::text = (storage.foldername(name))[1]
  );
