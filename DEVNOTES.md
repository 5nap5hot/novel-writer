# DEVNOTES

## Local-First Rule

IndexedDB remains the authoritative store for editing.

- The editor only writes locally.
- Sync reads from local data and pushes to Supabase later.
- Typing must never wait on network work.

## Auth And Ownership

Milestone 7 adds Supabase Auth and per-user project ownership without changing the local-first editing rule.

Rules:

- local IndexedDB remains the authoritative editing store
- project ownership is stored on the local project record as `ownerUserId`
- synced remote ownership is stored in Supabase as `user_id`
- in Supabase mode, only projects owned by the current authenticated user are loaded into the active app state
- direct project loads are filtered through the same ownership check

Current auth flows:

- sign up
- sign in
- sign out
- persistent Supabase session
- password reset email

Important local-first assumption:

- when a user signs in with Supabase on a device, previously anonymous local projects on that device are claimed for that user
- this keeps existing offline-first local work available for safe sync instead of hiding it
- chapter and scene ownership still derive from the parent project; only projects carry the explicit owner field locally

## Persisted Local Schema

Tables:

- `projects`
- `chapters`
- `scenes`
- `appState`
- `syncQueue`

Entity sync metadata:

- `lastEditedDeviceId`
- `lastSyncedAt`
- `remoteUpdatedAt`
- `syncError`
- `syncStatus`

Scene-only sync fields:

- `revision`
- `remoteRevision`
- `conflictState`
  - `none`
  - `local`
  - `remote_copy`
- `conflictGroupId`
- `remoteOriginalId`
- `syncSuppressed`

`appState` stores:

- `workspace-session`
- device identity
- per-scene editor session state

`syncQueue` stores durable local upsert work:

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

## Editor Content Schema

Persisted `contentJson` remains constrained to the Milestone 3 v1 schema:

- root `doc`
- `paragraph`
- `text`
- `bulletList`
- `listItem`

Allowed formatting only:

- `bold`
- `italic`
- `underline`
- `textStyle.fontSize`
  - preset tokens only: `sm`, `md`, `lg`, `xl`
- `textStyle.color`
  - optional six-digit hex color
- `paragraph.textAlign`
  - `left`
  - `center`
  - `right`
  - `justify`
- `paragraph.lineHeight`
  - preset tokens only: `normal`, `relaxed`, `double`

Plain text, word count, and character count are always derived from sanitized `contentJson`, never from formatted HTML or UI state.

## Sync Design

Milestone 4 uses conservative single-user sync.

Push phase:

1. read durable local queue
2. mark entity syncing
3. upsert current local entity to Supabase
4. mark synced and remove queue entry on success

Scene queue entries also carry the revision they were created from so stale scene pushes can be dropped safely.

Pull phase:

1. fetch remote rows for the authenticated user
2. compare remote entity freshness against local sync state
3. apply remote rows only when safe
4. preserve conflicts instead of overwriting prose

Sync triggers:

- app launch
- reconnect
- background interval while online
- manual sync action

## Versioning And Conflict Assumptions

Scene versioning assumptions are revision-based:

- every persisted local scene edit increments `revision`
- the last known synced remote scene revision is stored in `remoteRevision`
- remote scene freshness is based on remote `revision`
- timestamps remain for diagnostics only

Conflict detection for scenes:

- if local scene revision is greater than `remoteRevision`
- and remote scene revision is also greater than that same baseline
- treat it as a conflict
- do not overwrite either prose version

Conflict preservation behavior:

- keep the local scene in place
- mark it with `conflictState = local`
- create a separate local remote-copy scene
- mark the remote copy with `conflictState = remote_copy`
- suppress syncing of that remote-copy scene

## Non-Destructive Sync Assumptions

Ambiguous create/update/delete cases choose the safer path.

- Local deletions are not pushed remotely in v1.
- Remote deletions are ignored in v1.
- No automatic prose merge is attempted.
- The queue currently uses durable deduped upserts rather than delete tombstones.

## Known Limitations Before Milestone 5

- Conflict UI is intentionally minimal and does not provide merge tools.
- Project and chapter sync still use timestamp-oriented semantics; only scenes are revision-based right now.
- Supabase table names and column layout are currently code conventions and should be confirmed before production use.
- Queue retries are basic and there is no exponential backoff yet.
- Sync status is global and intentionally simple.

## Runtime Loop Fix

Second-pass root cause:

- The remaining infinite update path was inside `RichSceneEditor` in `src/features/workspace/EditorShell.tsx`.
- A `useEffect` that registered `pagehide` and `beforeunload` listeners also flushed scene saves and editor-session writes in its cleanup.
- In React Strict Mode and during editor-instance churn, that cleanup could run during normal rerender/remount cycles, not just true unload.
- The cleanup called `saveSceneDraft(...)`, which updates Zustand scene state and `activeProject.updatedAt`.
- That store write rerendered `WorkspaceScreen`, which kept the editor lifecycle hot and let the cleanup/write path repeat until React hit the maximum update depth guard.

Component and effect path involved:

1. `WorkspaceScreen` rerendered the selected workspace.
2. `RichSceneEditor` effect cleanup in `EditorShell.tsx` ran.
3. Cleanup called `flushSave()` and `onSaveSceneEditorState(...)`.
4. `saveSceneDraft(...)` in `src/state/appStore.ts` wrote new scene and project state to Zustand.
5. Zustand update rerendered the workspace again and repeated the same cleanup/write cycle.

Exact fix applied:

- `EditorShell.tsx`
  - removed Zustand-writing work from the `useEffect` cleanup that manages `pagehide` and `beforeunload`
  - kept unload/pagehide flushing in the event handler itself
  - moved editor persistence callbacks behind refs so the TipTap callbacks do not capture a fresh store-writing closure every rerender
  - limited `useEditor(...)` recreation to scene changes with a stable dependency list
- `WorkspaceScreen.tsx`
  - added a same-path guard before `navigate(...)` so it does not repeatedly replace the current route with the same URL
- selector wiring
  - object-shaped Zustand selectors now use `useShallow(...)` instead of the previous incompatible shallow-equality call shape

What was ruled out:

- `ProjectListScreen` refresh-on-mount was not the source of the loop
- `SyncManager` online/offline and interval effects were not the source of the initial load loop
- `AppBootstrap` restore logic was not repeatedly reinitializing the app after the first mount
- inline rename state in `InlineEditableText` was not creating the infinite update chain

Remaining risk areas:

- any future editor effect cleanup that writes to Zustand can recreate this class of loop
- same-route `navigate(..., { replace: true })` calls should always be guarded when driven by store state
- there is still a separate TypeScript build error in `src/db/repositories.ts` around a circular `RichTextContent` key-path type; that is unrelated to the runtime loop fix

## Chapter Context Fix

Root cause:

- `setSelectedChapter(...)` in `src/state/appStore.ts` was not a true chapter-only selection.
- Clicking a chapter set `selectedChapterId`, but it also auto-selected the first scene in that chapter when one existed.
- Separately, `WorkspaceScreen.tsx` had a route-sync effect that depended on `selectedSceneId`, so after a chapter click it could immediately re-apply the stale `:sceneId` from the current URL before the route updated.
- That made the old scene selection authoritative again, so `createSceneInSelectedChapter(...)` resolved chapter context from `selectedSceneId` and created the new scene under the wrong chapter.

Exact fix:

- `setSelectedChapter(...)` now sets `selectedSceneId` to `null`
- `resolveSelection(...)` now preserves chapter-only selection when a chapter id is preferred without a preferred scene id
- the route-to-store sync effect in `WorkspaceScreen.tsx` now runs only when the route `sceneId` itself changes, instead of rerunning on every `selectedSceneId` change

Authoritative selection rule:

- clicking a chapter means the chapter is authoritative and `selectedSceneId` becomes `null`
- clicking a scene means the scene is authoritative and its parent chapter becomes the selected chapter
- creating a new scene uses:
  - the selected scene's parent chapter when a scene is highlighted
  - otherwise the selected chapter when a chapter-only selection is highlighted

## Zoom Fix

Root cause:

- zoom state was persisting correctly, but the CSS application was ineffective
- `EditorShell.tsx` wrote `--editor-zoom` as a percentage string like `110%`
- `global.css` then used that percentage inside `font-size: calc(1.1rem * var(--editor-zoom, 100%) / 100)`
- that calculation did not produce a reliable applied font size for the TipTap prose element, so the displayed text never changed

Exact fix:

- the zoom value is now passed as a unitless scale variable: `--editor-zoom-scale`
- zoom is applied on `.editor-writing-column` with:
  - `font-size: calc(1.1rem * var(--editor-zoom-scale, 1))`
- `.novel-editor-content` now uses `font-size: 1em` so it inherits that scaled base size
- font-size presets were changed from `rem` values to `em` values so preset text also scales with zoom instead of staying fixed

Where zoom is applied:

- DOM: the CSS variable is set on the `.editor-writing-column` wrapper in `src/features/workspace/EditorShell.tsx`
- CSS: the actual text scaling is applied in `src/styles/global.css` on `.editor-writing-column`
- scope: only the writing column inherits the zoomed font size, so the toolbar, binder, and other UI do not scale

## Editor Shortcuts

Keyboard shortcuts are bound inside TipTap via `EditorShortcuts` in `src/features/workspace/editorExtensions.ts`.

Required shortcuts:

- `Cmd+B` / `Ctrl+B` -> toggle bold
- `Cmd+I` / `Ctrl+I` -> toggle italic
- `Cmd+U` / `Ctrl+U` -> toggle underline
- `Cmd+Shift+7` / `Ctrl+Shift+7` -> toggle bullet list
- `Cmd+Z` / `Ctrl+Z` -> undo
- `Cmd+Shift+Z` / `Ctrl+Shift+Z` -> redo

Scope:

## Trash Model

Milestone 6 Trash is implemented as a separate local table: `trashItems`.

Why it is separate:

- trashed chapters and scenes stay out of the active `chapters` and `scenes` tables used by the editor workspace
- active word counts, selection, composite view, and export can keep reading only active manuscript content
- delete remains non-destructive locally

Persisted trash item shape:

- `id`
- `projectId`
- `entityType`
  - `scene`
  - `chapter`
- `title`
- `deletedAt`
- `originalParentId`
- `originalIndex`
- `payload`
  - scene trash stores the full `SceneRecord`
  - chapter trash stores the full `ChapterRecord` plus all child `SceneRecord`s

Delete behavior:

- deleting a scene moves it to `trashItems`
- deleting a chapter moves the chapter and all of its scenes into one chapter trash item
- the existing 5-second undo toast still appears immediately after deletion
- local scene/chapter queue upserts are cleared when an item is moved to Trash so soft-deleted items are not accidentally pushed later

Undo and restore behavior:

- undo restores from the Trash entry rather than from an in-memory only snapshot
- explicit Restore actions in the Trash section use the same restore path
- restore tries to return to the original parent and original index
- if a scene's original chapter no longer exists, it restores to the first active chapter
- if no active chapter exists, a fallback `Recovered Scenes` chapter is created so the scene is still preserved

Permanent delete:

- permanent delete is only available inside Trash
- it removes the trash entry itself
- it does not touch active manuscript content

Important exclusions:

- trash items are not part of binder keyboard selection flow
- trash items do not appear in composite editor mode
- trash items do not count toward active project/chapter/scene counts
- trash items are excluded from export because export still reads only the active project bundle

## Trash Preview

Trash preview is a workspace-only override, not a manuscript selection change.

Behavior:

- clicking a Trash item selects it for preview in the composition window
- active binder chapter/scene selection is left intact underneath
- the preview disappears as soon as the user selects active manuscript content again

Preview rendering rules:

- trashed scenes render as a single-scene preview
- trashed chapters render as a composite stacked preview of that chapter's scenes
- both preview modes reuse the normal editor shell layout but set the scene editors to read-only

Read-only safety:

- TipTap editors are created with `editable: false`
- toolbar actions are disabled while previewing Trash
- scene title editing is replaced with static headings
- autosave, cursor persistence writes, and blur/pagehide save flushes are skipped in read-only preview mode
- preview does not enqueue sync work and does not mutate local scene content

Trash labels:

- chapter trash items render as `Chapter: {chapterName}`
- scene trash items render as `{chapterName} / {sceneName}`
- if the original chapter title is unavailable, the fallback is `Unknown Chapter / {sceneName}`

- the shortcuts only run when the editor is focused
- they do not override browser shortcuts outside the editor because the bindings live in the editor extension layer, not at the window level
- `Cmd+F` / `Ctrl+F` is handled separately in `EditorShell.tsx` at the document capture phase
- when focus is inside the Novel Writer workspace, Novel Writer prevents the browser's native find UI and opens the in-app find panel instead
- outside the workspace, the browser keeps its normal find shortcut behavior

## Composite Editor

Selection model:

- the store still keeps a primary `selectedChapterId` and `selectedSceneId` for routing and "new scene" context
- multi-selection is tracked separately with:
  - `selectedChapterIds`
  - `selectedSceneIds`
  - `selectionAnchorKey`
- single click resets the binder selection to the clicked item
- Cmd-click / Ctrl-click toggles the clicked chapter or scene into the selection
- Shift-click uses binder order to select a range from the anchor to the clicked item
- selecting a chapter automatically contributes all of that chapter's scenes to `selectedSceneIds`

Composite editor architecture:

- composite mode activates when more than one scene is selected
- the editor does not merge prose into one TipTap document
- instead, `EditorShell` renders ordered scene blocks, each with its own `RichSceneEditor` instance
- a shared toolbar sits above the stack and targets whichever scene editor most recently received focus
- scene dividers are rendered outside TipTap as non-editable DOM, so they cannot be modified as prose

Scene boundary protection:

- each scene still autosaves independently through the existing scene save path
- each scene keeps its own TipTap document, undo history, and editor session state
- there is no combined document, so typing, selections, and undo/redo cannot cross scene boundaries
- when composite mode opens, the first selected scene is focused at the top
- when returning to single-scene mode, that scene falls back to its own saved cursor/session restore path

## Find / Replace

Search architecture:

- `EditorShell` owns the find / replace panel state, search options, result list, and current match index
- search scans scene `contentText` first with a 250ms debounce
- editor highlight ranges are resolved from the same logical plain-text view of the ProseMirror document that search uses, so match indexes and decoration offsets stay aligned
- scope can be either:
  - current selection
  - entire project
- when the panel is open on `Entire Project`, the editor temporarily renders the whole project as a stacked scene scope so matches can be highlighted and replaced in mounted editors

Highlight implementation:

- TipTap decorations are provided by `SearchHighlightExtension`
- each mounted scene editor receives:
  - all local matches as yellow highlights
  - the active local match as a cyan highlight
- the search controller resolves per-editor highlight ranges from the scene editor's current plain text view before sending decoration ranges to the extension

Search scope rules:

- `Current Selection` uses the scene selection already active in the binder:
  - single scene
  - composite scene selection
  - chapter-driven multi-scene selection
- `Entire Project` uses all scenes in project order
- navigation and replace actions only operate inside the active scope

Search option behavior:

- `Contains` finds matches anywhere in the scoped scene text
- `Contains` matches the search text anywhere inside a word or phrase
- `Whole Word` matches only exact whole-word occurrences
- `Starts With` matches words whose beginning matches the search text
- `Ends With` matches words whose ending matches the search text

Find / replace highlight fix:

- root cause: highlights were offset because search was matching against a text string that included synthetic paragraph/list separators, while the decoration position map only counted raw text-node characters
- exact fix: `searchUtils.ts` now builds one shared searchable document view with:
  - the plain text used for match finding
  - the exact ProseMirror position map used for decorations and replace targets
- result: highlights, current-match focus, and replace operations now all use the same aligned match coordinates

Off-by-one follow-up:

- exact cause: the top-level ProseMirror node offset was seeded with an extra `+1` before recursive child position mapping, and the recursive traversal already adds the node-boundary offset needed for child content
- exact fix: `buildSearchableDocument(...)` now passes the top-level node position as `offset`, not `offset + 1`
- result: highlight and replace ranges now start on the first matched character instead of the character immediately after it
