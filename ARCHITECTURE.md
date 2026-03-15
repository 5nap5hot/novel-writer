# ARCHITECTURE

## Overview

Novel Writer is a desktop-first React + TypeScript + Vite application built around a local-first writing model.

Core principles:

- IndexedDB is the authoritative data store
- typing and local saves never wait on network work
- sync is additive and conservative
- prose is never auto-merged
- scenes are the primary editing unit, even in composite workflows

Main layers:

- UI: React components, React Router
- local app state: Zustand
- local persistence: Dexie over IndexedDB
- editor: TipTap with a constrained document model
- sync: local durable queue plus Supabase push/pull
- export: local-only ZIP and DOCX generation

## Editor Model

The editor is built with TipTap and configured in [`src/features/workspace/editorExtensions.ts`](./src/features/workspace/editorExtensions.ts).

Supported formatting:

- paragraphs
- text
- bold
- italic
- underline
- bullet lists
- alignment
  - left
  - center
  - right
  - justify
- font size presets
  - `sm`
  - `md`
  - `lg`
  - `xl`
- line spacing presets
  - `normal`
  - `relaxed`
  - `double`
- optional text color

The persisted editor schema is intentionally constrained. Rich text is stored as TipTap JSON, but content is sanitized before persistence so only the supported node and mark types remain.

Single-scene editing uses one TipTap instance per scene. Composite editor mode does not merge scenes into one document. Instead, it renders multiple scene editors in order, each with its own TipTap instance and autosave flow. Scene boundaries are enforced by rendering non-editable dividers outside the editor documents.

Zoom:

- zoom changes prose text size only
- zoom is applied via CSS on the writing column, not by scaling the whole UI
- zoom is persisted in workspace session state and restored on launch

Search:

- find/replace is controlled from `EditorShell`
- matches are found from scene plain text first
- highlights are rendered with TipTap decorations via a dedicated search highlight extension
- current match and non-current matches use distinct decoration classes

## Local Database Schema

Dexie defines the local IndexedDB schema in [`src/db/database.ts`](./src/db/database.ts).

Primary tables:

- `projects`
- `chapters`
- `scenes`
- `appState`
- `syncQueue`

### projects

Represents a novel project.

Key fields:

- `id`
- `title`
- `createdAt`
- `updatedAt`
- sync metadata such as `lastEditedDeviceId`, `lastSyncedAt`, `remoteUpdatedAt`, `syncError`, `syncStatus`

### chapters

Represents a chapter within a project.

Key fields:

- `id`
- `projectId`
- `title`
- `order`
- timestamps
- sync metadata

### scenes

Represents the main editing unit.

Key fields:

- `id`
- `projectId`
- `chapterId`
- `title`
- `order`
- `contentJson`
  - sanitized TipTap JSON
- `contentText`
  - derived plain text
- `wordCount`
  - derived from plain text only
- `characterCount`
  - derived from plain text only
- `revision`
  - monotonic local revision counter
- `remoteRevision`
  - last known synced remote revision
- conflict metadata
  - `conflictState`
  - `conflictGroupId`
  - `remoteOriginalId`
  - `syncSuppressed`

### appState

Stores application-level durable local state.

Examples:

- workspace session
- device identity
- per-scene editor session state
  - cursor position
  - scroll position

### syncQueue

Stores durable queued sync work.

Key fields:

- `id`
- `dedupeKey`
- `entityType`
- `entityId`
- `entityRevision`
- `operation`
- `createdAt`
- `updatedAt`
- `attemptCount`
- `lastAttemptAt`
- `lastError`

## Persistence And Restore

Repository functions in [`src/db/repositories.ts`](./src/db/repositories.ts) perform local writes and reads.

Persistence flow:

- editor updates local scene draft state immediately
- debounced saves persist sanitized `contentJson`, derived `contentText`, and counts
- workspace session stores last project, chapter, scene, chapter expansion state, and zoom
- per-scene editor state stores cursor and scroll

Restore flow:

- app bootstrap loads projects, workspace session, and device identity
- last project/chapter/scene selection is restored from IndexedDB
- binder chapter expansion state restores per project
- editor zoom restores from workspace session
- per-scene cursor and scroll restore when a scene editor mounts

## Sync Model

Sync is local-first and conservative.

Rules:

- IndexedDB remains authoritative
- local saves happen immediately
- sync never blocks typing
- prose is never auto-merged

### Queue Model

Local changes enqueue durable `upsert` work in `syncQueue`.

Design traits:

- queue entries are deduped by entity and operation
- scene queue entries carry `entityRevision`
- stale scene queue entries are dropped if their revision is older than the current local scene revision
- sync is designed to be idempotent where possible

### Sync Cycle

Sync runs:

- on app launch
- on reconnect
- on a background interval while online
- on manual sync

Order:

1. push queued local upserts
2. pull remote rows
3. apply safe remote updates locally

Current remote entities:

- projects
- chapters
- scenes

Current delete behavior is non-destructive:

- local deletes are not pushed remotely
- remote deletes are ignored

## Scene Revision System

Scenes use a monotonic revision counter as the primary change signal.

Rules:

- every persisted local scene save increments `revision`
- sync comparisons use scene revisions, not timestamps
- timestamps remain diagnostic metadata only

`remoteRevision` stores the last known synced remote revision for the scene.

### Conflict Handling

Scene conflicts are detected when:

- local scene revision is newer than the last synced baseline
- and the remote scene revision is also newer than that same baseline

Conflict policy is preserve-first:

- keep the local scene
- preserve the remote version as a separate local scene
- mark conflict state clearly
- suppress auto-sync of the remote conflict copy
- do not auto-merge prose

This keeps both versions available for manual resolution later.

## Search Behaviour

Find/replace is implemented in the workspace editor layer.

Core flow:

1. search scans scene plain text
2. matching ranges are resolved back into exact ProseMirror positions
3. TipTap decorations highlight all matches and the current match
4. replace actions operate on the current scoped editor match

Supported scopes:

- current selection
  - single scene
  - composite selection
  - chapter-driven selected scenes
- entire project

Supported search modes:

- `Contains`
  - matches search text anywhere inside a word or phrase
- `Whole Word`
  - matches exact whole-word occurrences only
- `Starts With`
  - matches words whose beginning matches the search text
- `Ends With`
  - matches words whose ending matches the search text

Options:

- ignore case
- ignore diacritics

Search input is debounced to avoid rescanning on every keystroke.

## Export

Export is local-only and does not depend on sync or the server.

Implementation lives in [`src/export/service.ts`](./src/export/service.ts).

### Safety ZIP

Generates a ZIP archive using `jszip`.

Structure mirrors the binder:

- `Project/`
- `Project/Chapter 01/`
- `Project/Chapter 01/Scene 01.md`

Content:

- Markdown derived from local rich text
- filenames are sanitized before writing

Preserved reasonably in Markdown:

- paragraphs
- bullet lists
- bold
- italic
- underline via inline HTML

### Scrivener Handoff DOCX

Generates a single DOCX manuscript using `docx`.

Structure:

- chapter titles as Heading 1
- scene titles as Heading 2
- scene body text follows the heading

Preserved where straightforward:

- paragraph content
- bullet lists
- bold
- italic
- underline
- basic color
- alignment
- line spacing
- font size presets mapped into DOCX runs

## Interaction Between Components

At a high level:

- React components render binder, editor, search UI, and export actions
- Zustand tracks active workspace selection and UI state
- repository functions handle all IndexedDB reads and writes
- TipTap editors edit scenes and emit local draft/save events
- sync reads local entities and queued work, then communicates with Supabase
- export reads local project bundles and produces downloadable artifacts

The main architectural boundary is intentional:

- editor logic edits scenes
- repository logic persists scenes
- sync logic moves durable entities between local storage and remote storage
- export logic reads local state and produces files

This separation keeps writing responsive while still allowing sync, search, and export to build on the same local data model.
