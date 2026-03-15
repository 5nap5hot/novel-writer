# TEST_PLAN

## Goal

This document lists the highest-value manual and automated test coverage areas for Novel Writer.

Focus on:

- local-first writing safety
- scene persistence correctness
- sync safety
- search accuracy
- export reliability

## 1. Core Flows

### Project, Chapter, And Scene Creation

Manual:

- create a new project and confirm it creates:
  - `New Novel`
  - `Chapter 1`
  - `Scene 1`
- confirm the new project opens directly into `Scene 1`
- create additional chapters and confirm default naming/order
- create scenes from:
  - a selected chapter
  - a selected scene
- confirm new scenes are created in the correct chapter context

Automation candidates:

- project creation seeds default structure
- chapter naming increments correctly
- scene naming increments correctly within a chapter
- new scene respects chapter context rules

### Typing And Formatting

Manual:

- type prose into a scene and confirm autosave
- use toolbar formatting:
  - bold
  - italic
  - underline
  - bullet list
  - alignment
  - font size presets
  - line spacing presets
- confirm formatting persists after scene switch and refresh

Automation candidates:

- sanitized `contentJson` only includes allowed schema
- plain text, word count, and character count derive correctly from rich text
- editor shortcuts apply the expected formatting

### Scene Switching And Persistence

Manual:

- switch between scenes rapidly and confirm no edits are lost
- reload the app and confirm restore of:
  - last project
  - last chapter
  - last scene
  - chapter expansion state
- verify inline renaming does not break selection or navigation

Automation candidates:

- scene draft save queue preserves latest edit
- chapter expansion persists per project
- scene selection restore uses persisted workspace session

### Zoom And Search

Manual:

- change zoom and confirm prose text size changes while UI chrome does not
- switch scenes and refresh to confirm zoom persistence
- test search modes:
  - Contains
  - Whole Word
  - Starts With
  - Ends With
- verify highlight alignment, current-match styling, and replace behavior

Automation candidates:

- search mode matching semantics
- match-to-editor position mapping
- replace operates on the exact active match

## 2. Sync And Offline

### Offline Editing

Manual:

- disconnect network
- create/edit/rename scenes locally
- confirm writing remains responsive and data persists locally
- confirm sync status shows offline or saved locally appropriately

Automation candidates:

- local writes succeed with sync unavailable
- sync queue entries are created for local changes

### Reconnect And Sync

Manual:

- reconnect network after offline edits
- trigger sync manually or wait for reconnect sync
- confirm queued changes clear and status moves to synced when appropriate

Automation candidates:

- background sync runs only when online and authenticated
- stale queue entries do not push over newer revisions

### Conflict Scenarios

Manual:

- simulate divergent local and remote scene revisions
- confirm both local and remote copies are preserved
- confirm conflict notice is visible and non-destructive

Automation candidates:

- conflict detection on revision divergence
- remote conflict copy gets a new local id
- remote conflict copy is `syncSuppressed`

## 3. Export

### ZIP And DOCX Export

Manual:

- export Safety ZIP and confirm folder structure mirrors the binder
- export DOCX and confirm chapter/scene heading structure
- confirm filenames are sanitized

Automation candidates:

- ZIP path generation
- DOCX structure generation
- filename sanitization

### Formatting Fidelity

Manual:

- verify exported content preserves:
  - paragraphs
  - bullet lists
  - bold
  - italic
  - underline
- confirm expected simplification for features not fully preserved across formats

## 4. General UI

Manual:

- verify keyboard shortcuts:
  - formatting shortcuts
  - undo/redo
  - find shortcut
- verify binder multi-selection and composite editor behavior
- check layout and usability on smaller desktop/tablet widths
- confirm draggable floating find panel behaves correctly while editor scrolls

Automation candidates:

- selection model rules
- composite editor scene ordering
- current chapter context for `New Scene`

## 5. Error Handling

Manual:

- force a runtime error and confirm the route error boundary renders
- simulate network failure during sync and confirm the app remains usable
- confirm sync failures do not block local editing

Automation candidates:

- sync failure updates status without destroying local state
- route error boundary renders on thrown route/component errors

## Regression Priorities

When fixing bugs, prefer adding regression coverage for:

- scene revision handling
- stale queue handling
- conflict preservation
- selection and chapter context rules
- search highlight alignment
- replace correctness
- restore and autosave behavior
