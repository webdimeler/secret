-- Device registry and private file metadata for Secret KFS.
-- The same schema has already been applied to the linked Supabase project.
create table if not exists public.connected_devices (
  id uuid primary key default gen_random_uuid(),
  device_name text not null default 'Android device',
  platform text not null default 'android' check (platform in ('android')),
  app_version text,
  status text not null default 'pending' check (status in ('pending','active','revoked')),
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists connected_devices_status_last_seen_idx
  on public.connected_devices (status, last_seen_at desc);

create table if not exists public.device_files (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.connected_devices(id) on delete cascade,
  storage_path text not null unique,
  file_name text not null,
  mime_type text,
  size_bytes bigint not null default 0 check (size_bytes >= 0),
  created_at timestamptz not null default now()
);
create index if not exists device_files_device_created_idx
  on public.device_files (device_id, created_at desc);

alter table public.connected_devices enable row level security;
alter table public.device_files enable row level security;
revoke all on public.connected_devices from anon, authenticated;
revoke all on public.device_files from anon, authenticated;
grant select, insert, update, delete on public.connected_devices to authenticated;
grant select, insert, update, delete on public.device_files to authenticated;

drop policy if exists "admins manage connected devices" on public.connected_devices;
create policy "admins manage connected devices" on public.connected_devices
for all to authenticated
using (exists (
  select 1 from public.admin_accounts a
  where a.email = lower(coalesce(auth.jwt()->>'email','')) and a.is_active
))
with check (exists (
  select 1 from public.admin_accounts a
  where a.email = lower(coalesce(auth.jwt()->>'email','')) and a.is_active
));

drop policy if exists "admins manage device files" on public.device_files;
create policy "admins manage device files" on public.device_files
for all to authenticated
using (exists (
  select 1 from public.admin_accounts a
  where a.email = lower(coalesce(auth.jwt()->>'email','')) and a.is_active
))
with check (exists (
  select 1 from public.admin_accounts a
  where a.email = lower(coalesce(auth.jwt()->>'email','')) and a.is_active
));

insert into storage.buckets (id, name, public, file_size_limit)
values ('device-files', 'device-files', false, 52428800)
on conflict (id) do update set public = false, file_size_limit = 52428800;

drop policy if exists "admins access device files bucket" on storage.objects;
create policy "admins access device files bucket" on storage.objects
for all to authenticated
using (
  bucket_id = 'device-files' and exists (
    select 1 from public.admin_accounts a
    where a.email = lower(coalesce(auth.jwt()->>'email','')) and a.is_active
  )
)
with check (
  bucket_id = 'device-files' and exists (
    select 1 from public.admin_accounts a
    where a.email = lower(coalesce(auth.jwt()->>'email','')) and a.is_active
  )
);

alter table public.connected_devices add column if not exists device_token_hash text;
create table if not exists public.device_pairing_codes (
  id uuid primary key default gen_random_uuid(),
  code_hash text not null unique,
  created_by text not null,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists device_pairing_codes_expiry_idx
  on public.device_pairing_codes (expires_at) where used_at is null;
alter table public.device_pairing_codes enable row level security;
revoke all on public.device_pairing_codes from anon, authenticated;
grant select, insert, update, delete on public.device_pairing_codes to authenticated;
drop policy if exists "admins manage device pairing codes" on public.device_pairing_codes;
create policy "admins manage device pairing codes" on public.device_pairing_codes
for all to authenticated
using (exists (
  select 1 from public.admin_accounts a
  where a.email = lower(coalesce(auth.jwt()->>'email','')) and a.is_active
))
with check (exists (
  select 1 from public.admin_accounts a
  where a.email = lower(coalesce(auth.jwt()->>'email','')) and a.is_active
));
