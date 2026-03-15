create table if not exists public.novel_projects (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  last_edited_device_id text
);

create table if not exists public.novel_chapters (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  project_id text not null references public.novel_projects(id) on delete cascade,
  title text not null,
  order_index integer not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  last_edited_device_id text
);

create table if not exists public.novel_scenes (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  project_id text not null references public.novel_projects(id) on delete cascade,
  chapter_id text not null references public.novel_chapters(id) on delete cascade,
  title text not null,
  content_json jsonb not null,
  content_text text not null,
  word_count integer not null,
  character_count integer not null,
  order_index integer not null,
  revision integer not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  last_edited_device_id text
);

alter table public.novel_projects enable row level security;
alter table public.novel_chapters enable row level security;
alter table public.novel_scenes enable row level security;

drop policy if exists "projects owner select" on public.novel_projects;
drop policy if exists "projects owner insert" on public.novel_projects;
drop policy if exists "projects owner update" on public.novel_projects;
drop policy if exists "chapters owner select" on public.novel_chapters;
drop policy if exists "chapters owner insert" on public.novel_chapters;
drop policy if exists "chapters owner update" on public.novel_chapters;
drop policy if exists "scenes owner select" on public.novel_scenes;
drop policy if exists "scenes owner insert" on public.novel_scenes;
drop policy if exists "scenes owner update" on public.novel_scenes;

create policy "projects owner select"
on public.novel_projects for select
to authenticated
using (user_id = auth.uid());

create policy "projects owner insert"
on public.novel_projects for insert
to authenticated
with check (user_id = auth.uid());

create policy "projects owner update"
on public.novel_projects for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "chapters owner select"
on public.novel_chapters for select
to authenticated
using (user_id = auth.uid());

create policy "chapters owner insert"
on public.novel_chapters for insert
to authenticated
with check (user_id = auth.uid());

create policy "chapters owner update"
on public.novel_chapters for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "scenes owner select"
on public.novel_scenes for select
to authenticated
using (user_id = auth.uid());

create policy "scenes owner insert"
on public.novel_scenes for insert
to authenticated
with check (user_id = auth.uid());

create policy "scenes owner update"
on public.novel_scenes for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
