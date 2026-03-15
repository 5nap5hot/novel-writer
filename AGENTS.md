# AGENTS

## Purpose

This file explains how AI coding agents should work in the Novel Writer codebase.

Novel Writer is a local-first writing application. The most important rule is that user writing must remain safe, immediate, and non-destructive.

When in doubt:

- preserve local data
- avoid destructive changes
- prefer incremental architecture-aligned work over clever shortcuts

## Key Architecture Rules

### 1. Local-First Storage

IndexedDB is the authoritative application data store.

Implications:

- local edits must work without network access
- typing must never wait on sync
- new features should read from and write to the local repository layer first
- Supabase is a sync target, not the primary source of truth during editing

Primary persistence code lives in:

- `src/db/database.ts`
- `src/db/repositories.ts`
- `src/db/session.ts`

### 2. Revision-Based Scene Versioning

Scenes use a monotonic integer `revision`.

Rules:

- every persisted scene save increments `revision`
- sync comparisons for scenes use revision, not timestamps
- timestamps are diagnostic metadata only
- queue entries for scenes must carry `entityRevision`

Do not replace revision-based comparison with timestamp-only logic.

### 3. TipTap Editor Schema Constraints

The persisted editor schema is intentionally limited.

Allowed content/features:

- `doc`
- `paragraph`
- `text`
- `bulletList`
- `listItem`
- bold
- italic
- underline
- paragraph alignment
- font size presets
- line spacing presets
- optional text color

Do not introduce new persisted TipTap node types, marks, or attributes without explicit approval.

If you change editor behavior:

- preserve schema sanitation
- preserve plain-text derivation
- preserve per-scene isolation

Relevant files:

- `src/features/workspace/editorExtensions.ts`
- `src/lib/editorContent.ts`
- `src/features/workspace/EditorShell.tsx`

### 4. Non-Destructive Sync And Conflict Handling

Sync is conservative by design.

Rules:

- local data remains authoritative
- prose is never auto-merged
- conflicts must preserve both local and remote copies
- stale queue entries must not overwrite newer revisions
- deletions are intentionally conservative

Do not introduce destructive conflict resolution or silent overwrite behavior.

Relevant files:

- `src/sync/service.ts`
- `src/state/appStore.ts`
- `src/db/repositories.ts`
- `SYNC_DESIGN.md`

## Do's And Don'ts

### Do

- do favor safety, traceability, and data preservation
- do use existing repository functions and models as the source of truth
- do preserve local-first behavior when adding features
- do keep scene boundaries intact
- do update documentation when changing architecture behavior
- do prefer explicit, readable logic over hidden abstractions
- do maintain per-scene autosave and restore behavior
- do treat `contentJson`, `contentText`, counts, and `revision` as linked persisted state

### Don't

- do not add arbitrary editor features without approval
- do not expand the TipTap schema casually
- do not bypass IndexedDB and write new features directly against Supabase
- do not add destructive sync behavior or auto-merge prose
- do not change revision semantics without understanding stale queue and conflict handling
- do not introduce drag-and-drop or collaborative editing behavior unless explicitly requested
- do not treat timestamps as the primary version signal for scenes
- do not create hidden background mutations that can interfere with editor rendering or selection

## Source Of Truth

When making changes, use these as the primary references:

- architecture overview: `ARCHITECTURE.md`
- sync behavior: `SYNC_DESIGN.md`
- implementation notes and known edge cases: `DEVNOTES.md`
- data models: `src/types/models.ts`
- persistence layer: `src/db/repositories.ts`
- workspace/editor behavior: `src/features/workspace/*`
- app state and selection logic: `src/state/appStore.ts`

If code and docs conflict, inspect the current implementation carefully and update docs if needed as part of the change.

## Common Tasks

### Adding A New Feature

When adding a feature:

1. Identify whether it belongs to:
   - editor layer
   - UI layer
   - local persistence layer
   - sync layer
   - export layer
2. Confirm how it should behave offline first.
3. Reuse existing models and repository functions where possible.
4. Avoid changing persisted schema unless necessary.
5. If schema changes are necessary:
   - update Dexie schema carefully
   - update models
   - update repository read/write logic
   - update docs
6. Confirm the feature does not break:
   - scene autosave
   - revision increments
   - selection restoration
   - sync queue safety

Good default approach:

- implement local behavior first
- make state explicit
- keep sync concerns separate unless the task is specifically about sync

### Updating The Sync Model

Before changing sync behavior:

1. Read:
   - `SYNC_DESIGN.md`
   - `src/sync/service.ts`
   - sync-related code in `src/db/repositories.ts`
2. Identify whether the change affects:
   - queue durability
   - revision comparison
   - stale queue handling
   - conflict detection
   - conflict preservation
3. Prefer non-destructive behavior when rules are ambiguous.
4. Preserve idempotency where possible.
5. Never allow stale local queue data to overwrite newer revisions.
6. Document the exact rule change in `SYNC_DESIGN.md` and `DEVNOTES.md`.

If a sync rule is ambiguous, choose the safer path:

- preserve data
- avoid deletion
- avoid auto-merge

### Adding A New Export Format

Current export logic lives in:

- `src/export/service.ts`

Rules for export work:

- export from local IndexedDB data only
- do not depend on the server
- do not modify sync logic just to support export
- preserve scene order and chapter order
- sanitize filenames when writing file-based exports

When adding a format:

1. Use `getProjectBundle(...)` or equivalent local repository reads.
2. Convert from sanitized local scene content.
3. Be explicit about what formatting is preserved and what is simplified.
4. Update `README.md`, `ARCHITECTURE.md`, and `DEVNOTES.md` if behavior changes materially.

### Modifying The Editor

Before changing editor behavior:

1. Check schema constraints in `src/lib/editorContent.ts`.
2. Check current TipTap extensions in `src/features/workspace/editorExtensions.ts`.
3. Confirm whether the change affects:
   - persisted `contentJson`
   - plain-text derivation
   - counts
   - search mapping
   - export behavior
4. Preserve scene isolation.

Do not treat composite mode as one merged document. It is intentionally a stack of separate scene editors.

### Modifying Search

Search currently:

- scans plain text first
- maps matches back into exact ProseMirror positions
- applies TipTap decorations
- performs replace using those exact mapped ranges

When changing search:

- keep matching logic and highlight mapping aligned
- verify offsets at:
  - paragraph start
  - punctuation boundaries
  - repeated matches in one paragraph
  - multi-scene composite mode
- update `DEVNOTES.md` with exact semantics if behavior changes

### Modifying Selection Or Composite Editor Behavior

Selection logic is subtle.

Before changing it:

1. Inspect `src/state/appStore.ts`
2. Inspect `src/binder/BinderSidebar.tsx`
3. Inspect `src/features/workspace/WorkspaceScreen.tsx`
4. Inspect `src/features/workspace/EditorShell.tsx`

Preserve these rules unless explicitly changing them:

- chapter click can define chapter context
- scene click defines scene context
- multi-selection is additive and separate from primary route context
- composite mode must keep scenes internally separate
- edits must not cross scene boundaries

### Adding Or Modifying Test Cases

If the project has or gains automated tests, prefer:

- focused unit tests for pure logic
  - search semantics
  - revision handling
  - conflict detection
  - filename sanitation
- integration tests for:
  - selection behavior
  - composite editor mode
  - autosave and restore
  - export outputs

High-value test areas:

- scene revision increments
- stale queue rejection
- conflict preservation
- chapter-context `New Scene`
- search offset correctness
- replace behavior across repeated matches
- composite editor scene isolation

When adding tests:

- keep them close to the behavior they validate
- prefer deterministic fixtures
- include regression coverage for any bug you fix

## Safe Change Checklist

Before finishing a change, verify:

- local editing still works offline
- scene saves still increment revision when appropriate
- sync logic was not accidentally bypassed or broken
- search, export, or counts still rely on local canonical data
- no destructive overwrite path was introduced
- docs were updated if behavior or architecture changed

## If You Are Unsure

If a requested change appears to conflict with the current architecture:

- pause and identify the architectural tension clearly
- prefer the existing local-first, non-destructive model
- ask for approval before broadening schema, sync semantics, or editor capabilities

The safest default is:

- keep data local
- preserve both versions
- avoid destructive behavior
- make the change explicit and documented
