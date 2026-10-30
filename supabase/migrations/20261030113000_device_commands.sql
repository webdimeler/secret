create table if not exists public.device_commands (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.connected_devices(id) on delete cascade,
  command text not null check (command in ('browse_files')),
  status text not null default 'pending' check (status in ('pending','completed','failed')),
  result jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

alter table public.device_commands enable row level security;

create index if not exists device_commands_pending_idx
  on public.device_commands (device_id, status, created_at);
