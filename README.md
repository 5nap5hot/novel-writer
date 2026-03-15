# Novel Writer

Novel Writer is a desktop-first React + TypeScript + Vite app for drafting fiction with a local-first binder:

- Project
- Chapters
- Scenes

Milestones 1 through 7 are implemented:

- local-first IndexedDB persistence with Dexie
- TipTap editor with constrained rich text JSON
- per-project binder restore and workspace restore
- local sync queue
- Supabase-backed push/pull sync for authenticated users
- Supabase Auth sign up / sign in / sign out / reset password
- per-user project ownership
- conflict preservation for scenes
- local export to ZIP and DOCX

## Stack

- React
- TypeScript
- Vite
- React Router
- Dexie
- Zustand
- Supabase
- TipTap
- JSZip
- docx

## Local Setup

1. Install Node.js 20 or newer.
2. Install dependencies:

```bash
npm install
```

3. Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

4. Fill in:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

5. Start the app:

```bash
npm run dev
```

## Hosted Deployment

Novel Writer can also be deployed as a hosted web app while keeping local-first editing in the browser on each device.

For the recommended deployment flow, see:

- `DEPLOYMENT.md`

The short version:

1. deploy to Vercel
2. add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`
3. add your deployed app URL in Supabase auth settings
4. sign in from any browser

## Supabase Auth And Sync Setup

Enable Supabase Auth with email/password.

Required app flows now supported:

- sign up
- sign in
- sign out
- persistent session
- password reset email

## Supabase Data Setup

Milestone 4 expects three remote tables:

- `novel_projects`
- `novel_chapters`
- `novel_scenes`

Suggested columns:

- `novel_projects`
  - `id text primary key`
  - `user_id uuid not null`
  - `title text not null`
  - `created_at timestamptz not null`
  - `updated_at timestamptz not null`
  - `last_edited_device_id text`
- `novel_chapters`
  - `id text primary key`
  - `user_id uuid not null`
  - `project_id text not null`
  - `title text not null`
  - `order_index integer not null`
  - `created_at timestamptz not null`
  - `updated_at timestamptz not null`
  - `last_edited_device_id text`
- `novel_scenes`
  - `id text primary key`
  - `user_id uuid not null`
  - `project_id text not null`
  - `chapter_id text not null`
  - `title text not null`
  - `content_json jsonb not null`
  - `content_text text not null`
  - `word_count integer not null`
  - `character_count integer not null`
  - `order_index integer not null`
  - `created_at timestamptz not null`
  - `updated_at timestamptz not null`
  - `last_edited_device_id text`

Recommended RLS direction:

- users can only read/write rows where `user_id = auth.uid()`

Recommended project ownership column locally and remotely:

- local `projects.ownerUserId`
- remote `novel_projects.user_id`

Suggested RLS policies:

```sql
alter table novel_projects enable row level security;
alter table novel_chapters enable row level security;
alter table novel_scenes enable row level security;

create policy "projects owner select"
on novel_projects for select
to authenticated
using (user_id = auth.uid());

create policy "projects owner insert"
on novel_projects for insert
to authenticated
with check (user_id = auth.uid());

create policy "projects owner update"
on novel_projects for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "chapters owner select"
on novel_chapters for select
to authenticated
using (user_id = auth.uid());

create policy "chapters owner insert"
on novel_chapters for insert
to authenticated
with check (user_id = auth.uid());

create policy "chapters owner update"
on novel_chapters for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "scenes owner select"
on novel_scenes for select
to authenticated
using (user_id = auth.uid());

create policy "scenes owner insert"
on novel_scenes for insert
to authenticated
with check (user_id = auth.uid());

create policy "scenes owner update"
on novel_scenes for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
```

Unauthenticated users should have no project data access.

## Ownership Model

- every synced project belongs to one authenticated user
- project ownership is stored locally in `ownerUserId`
- signed-in users only load projects whose `ownerUserId` matches their Supabase user id
- direct project access is rejected locally if ownership does not match the signed-in user
- on first Supabase sign-in on a device, previously anonymous local projects are claimed for that user so local-first work can sync safely

## Sync Behavior

IndexedDB remains the authoritative editing store.

Sync runs:

- on app launch
- on reconnect
- on a background interval while online
- on manual sync

Sync order:

1. push queued local upserts
2. pull remote rows
3. apply newer remote rows only when safe

Current sync status UI states:

- saved locally
- syncing
- synced
- offline
- conflict
- sync failed

## Non-Destructive Rules

- Typing and local saves never wait on sync.
- Sync never blocks editing.
- Scene prose is never auto-merged.
- On scene conflict, the local scene is preserved and a separate remote conflict copy is preserved locally.
- Local deletions are currently non-destructive and are not pushed remotely in v1.
- Remote deletions are currently ignored in v1.

## Local Schema

IndexedDB stores:

- `projects`
- `chapters`
- `scenes`
- `appState`
- `syncQueue`
- `trashItems`

Each entity now also stores sync metadata such as:

- `lastEditedDeviceId`
- `lastSyncedAt`
- `remoteUpdatedAt`
- `syncError`
- `syncStatus`

Scenes also store:

- `conflictState`
- `conflictGroupId`
- `remoteOriginalId`
- `syncSuppressed`

Projects also store:

- `ownerUserId`

## File Structure

```text
novel-writer/
  src/
    app/
      AppBootstrap.tsx
    binder/
      BinderSidebar.tsx
    components/
      AppHeader.tsx
      ExportMenu.tsx
      InlineEditableText.tsx
      SyncStatusBadge.tsx
    db/
      database.ts
      repositories.ts
      session.ts
    features/
      auth/
        LoginScreen.tsx
      projects/
        ProjectListScreen.tsx
      workspace/
        EditorShell.tsx
        EditorToolbar.tsx
        WorkspaceScreen.tsx
        editorExtensions.ts
    export/
      service.ts
    lib/
      editorContent.ts
      id.ts
      supabase.ts
      time.ts
    routes/
      router.tsx
    state/
      appStore.ts
    styles/
      global.css
    sync/
      service.ts
      SyncManager.tsx
    types/
      models.ts
```

## Export

Milestone 5 adds two local-only export modes from IndexedDB:

- Safety export
  - ZIP archive
  - binder-shaped folders and files:
    - `Project/Chapter 01/Scene 01.md`
- Scrivener handoff export
  - single DOCX manuscript
  - chapter titles as Heading 1
  - scene titles as Heading 2

Exports do not require sync or Supabase and use local IndexedDB data only.

## Current Limitations

- No collaborative editing.
- No automatic prose merge.
- Sync assumes a single authenticated owner per dataset.
- Conflict handling is intentionally minimal and preserves copies instead of resolving them.
- Delete sync semantics are intentionally conservative and currently local-only.
