# Novel Writer Native Dev Handoff

## Maintenance Rule

After any meaningful feature, behavior, storage, sync, or workflow change, update this file before ending the work session.

This is the canonical developer handoff for switching Macs and resuming work in Codex.

## Resume Project

Project path:
`/Users/mikecarmel/Documents/XcodeProject/Novel Writer Native.xcodeproj`

Primary app file:
`/Users/mikecarmel/Documents/XcodeProject/Novel Writer Native/ContentView.swift`

## Current State

- Native macOS proof of concept is building and running.
- Binder, project library, persistence, drag reorder, trash, undo, rename, composite view, rich text, toolbar basics, and assistant sidebar are working.
- Cross-Mac phase 1 sync is working through a user-chosen storage folder, including iCloud Drive.
- Sync safety polish is now in:
  - exact storage path shown on the Projects screen
  - automatic backup folder path shown on the Projects screen
  - `Reload From Disk`
  - `Last saved` status
  - external-change notice when the storage file changes outside the current app window
  - revision-based save-time write guard: a stale window now refuses to save over a newer on-disk version until reloaded
  - stale-data warning is shown in both the Projects screen and the main workspace
  - saved snapshots now carry an internal revision number, so sync checks no longer rely only on file timestamps
  - clearer storage permission errors now tell the user to click `Choose Folder` again if this Mac loses write access to the shared iCloud folder bookmark
  - custom shared-folder access is now started once for the whole app session instead of reopening only around each file operation
  - remembered assistant API keys now prefer app-local remembered storage on this Mac, which should avoid repeated local-password prompts in dev builds
  - savepoints now flush when the app resigns active, quits, or the Mac goes to sleep, which helps with close-the-lid laptop handoff
  - rolling automatic snapshot backups now write into `Automatic Backups` inside the chosen storage folder
  - automatic backups are created at most once every 10 minutes during normal saves
  - retention keeps dense recent history for the last 24 hours and then one backup per day for 30 days
  - project cards now have `Restore Backup…`, which opens an in-app picker for that project’s automatic snapshots and restores only that project
  - restore now confirms before replacing a project, and creates one more safety snapshot of the current project first
  - app background / quit / sleep savepoints now force immediate project backup snapshots for changed projects instead of waiting for the normal 10-minute cadence
  - deleting a project now creates a final project backup snapshot before moving it to Trash
- Podcast mode foundation is in:
  - project-level podcast setup in Style Guide
  - chapter/episode naming support
  - episode prep drawer
  - GPT-powered episode pack generation
- App icon set now exists in the asset catalog and uses the warm literary palette.
- Projects screen now shows the app version/build so two Macs can be checked against the same build quickly.

## Cross-Mac Workflow

- App data now lives in a user-selectable storage folder.
- Current intended use is one Mac at a time, not simultaneous editing.
- Normal editing already persists continuously as you work; savepoint flushes now also happen on app background/quit/sleep.
- On a second Mac:
  1. Run the same app build.
  2. Go to the Projects screen.
  3. Click `Choose Folder`.
  4. Point it at the same iCloud Drive folder used on the first Mac.

## Important Current Limitation

- This is file sync, not true record-level sync.
- If both Macs edit before iCloud finishes syncing, conflicts are possible.

## Recent Major Additions

- Assistant continuity memory:
  - project-level continuity memory field
  - assistant can update it from current scope
  - continuity memory now feeds normal assistant chat and scene review
- Character voice system:
  - project-wide style rules
  - character-specific voice rules
  - assistant can build and merge character voice drafts
  - character voice drafts now separate durable character notes from project-wide consistency notes
  - adding a character voice draft now merges any project-wide consistency notes into the novel-wide style guide
  - approved-word filtering is stricter now, so generic filler terms are less likely to land in character approved words
  - character voice draft prompts now require a fuller standardized sheet format with explicit POV/tense, approved words/recurring phrases, consistency risks, preserve-in-rewrites guidance, do/don't rules, and quick sample lines
  - character guide drafts now also generate a standardized canonical physical-description sheet and merge it into the character `Visual Description` field
  - assistant build UI now labels this tool as `Build Character` instead of `Build Character Voice`, since it now produces both voice and physical-description sheets
  - assistant `Build` and `Draft` menus now hide the extra system menu indicator so only the intended right-side chevron remains
- Project direction system:
  - narrative person
  - narrative tense
  - genre
  - subgenre
  - story promise
  - pacing / arc notes
  - avoid / flag notes
- Assistant review workflow:
  - review scene
  - linked issue cards
  - editor jump
  - approve / decline
  - approve all safe
  - manual edit tracking for stale issues
  - assistant panel text baseline has been bumped so it reads closer to the manuscript/editor scale
  - review prompts now prefer returning concrete replacements for localized dialogue/prose/repetition fixes instead of only commentary when a safe line-level rewrite is practical
  - assistant header/actions/composer have been tightened to reduce crowding: fewer always-visible quick actions, stronger composer card treatment, and a more compact bottom bar
  - the bottom prompt is now explicitly labeled `Message` with a placeholder hint and stronger section separation so it stays visible even when empty
  - OpenAI assistant/podcast requests now use a longer timeout window and retry once on real timeout/network-drop errors, with clearer timeout messaging in the UI
  - model split now favors quality where judgment matters most:
    - routine chat / style-guide / continuity / podcast generation stay on `gpt-5-mini`
    - `Review Scene`, `Build Character Voice`, and `Propose Scene Breaks` now use `gpt-5.4`
    - previous-episode recap generation now also uses `gpt-5.4`: both when regenerating just that section and when generating a full episode pack for a non-first episode
  - the assistant footer now shows the actual model last used, and highlights it while a request is in flight
  - review passes no longer append the extra bottom summary block when issues are found; the cards themselves are the review
  - review prompts now push harder for direct replacements on formatting cleanup, quote fixes, line-break normalization, casing/emphasis cleanup, and other obvious local fixes
- Find / Replace:
  - drawer UI in binder footer
  - scopes
  - modes
  - `Match Case` toggle
  - opening Find / Replace now actively focuses the find field so `Cmd+F` is ready to type immediately
  - `Cmd+G` now advances to the next search match directly from the editor while keeping focus in the manuscript text view
  - replace, replace next, replace all
  - stable undo flow
  - all visible matches now highlight in the editor
  - the active match now gets a stronger distinct highlight
- Editor performance:
  - scene typing no longer triggers a full persisted snapshot write on every keystroke
  - normal scene body/rich-text/edit-location saves are now coalesced briefly while typing
  - single-scene editor no longer regenerates full RTF on every keystroke; rich-text snapshotting is debounced and flushed when editing ends
  - plain-text sync back into SwiftUI is now intentionally lazier during active typing to reduce rubber-banding while correcting text
  - caret-location persistence is no longer pushed on every keystroke; selection sync is slower and handled outside the normal typing path
  - rich-text capture is now noticeably less frequent during active editing so backspacing and quick corrections feel smoother
  - pasted text in scene editors now normalizes to the active typing attributes, so it adopts the current font size, color, and paragraph styling instead of importing outside formatting
  - the writing column is now substantially wider, using more of the available editor width while still preserving side margins
  - editor zoom is now a separate persisted setting with options from `100%` through `300%`, so readability can scale independently of the base font-size preset
  - editor toolbar now has a reveal-invisibles toggle that shows paragraph marks, tabs, and spaces without changing the underlying text
  - when reveal-invisibles is on, the Find / Replace inputs now show pasted paragraph breaks, tabs, and spaces inside the fields themselves
  - the Find / Replace inputs are now vertically growing multiline fields, so pasted paragraph markers expand the field height and Return inserts new lines
  - app background / quit / sleep still force an immediate savepoint
- Podcast mode:
  - podcast project toggle in Style Guide
  - podcast title / host / URLs / CTA fields
  - Style Guide now also includes project-level `Audio Pronunciations` replacements for TTS/audio-production output, keeping manuscript spellings intact while allowing phonetic output forms like `Sharael -> Shuhrel`
  - episode prep drawer
  - drawer now opens from the binder/editor seam instead of the far right side
  - left-side drawer handle now points right when closed and left when open
  - generated intro, outro, summary, cover-art prompt, and platform posts
  - if the current episode is not the first one, episode prep now also includes a `Previous Episode Summary` field before the intro
  - previous-episode recap generation now looks at the prior episode, infers its dominant POV/voice, and drafts the recap in the opposite POV by default
  - previous-episode recap now has its own character dropdown populated from established character voices so the user can change POV and regenerate
  - previous-episode recap is now treated as a true previously-on summary rather than spoiler-safe teaser copy, and targets roughly 60 to 100 words when the prior episode meaningfully warrants it
  - previous-episode recap prompting is now stricter about staying concrete and event-grounded: it should prefer on-page actions and immediate consequences over trailer phrasing or editorial lines like "stolen comfort," "they press onward," or "no longer alone"
  - per-section regenerate actions in the episode drawer
  - copy buttons for each section
  - `Copy Episode Pack` action
  - the small quick-action icon in the episode drawer header is now `Export RTF`, opening a save panel for an RTF episode-pack export instead of duplicating the existing copy-pack action
  - `Copy Episode Pack for TTS` now applies enabled audio-pronunciation replacements with whole-word matching, sorted longest-first to reduce overlap issues
  - `Generate Missing Only` action for incomplete episode packs
  - `Export Pack` action for plain-text export of the whole episode prep set
  - internal code naming for the old `podcastSummary` field has now been cleaned up to `podcastDescription`, while keeping the saved project key and OpenAI JSON field stable so no migration was needed
  - intro/outro voices now auto-fill from the preferred host or first character voice when blank
  - intro/outro voice picking is now simplified to one dropdown each instead of duplicated text-entry plus dropdown controls
  - episode prep now has an editable generated episode title field
  - the episode title field is no longer auto-filled from the chapter title on drawer load; leaving it empty now correctly lets `Generate Pack` propose a title
  - if the user edits that episode title and then refreshes/regenerates the full pack, the edited title is now treated as locked user input and reused consistently across intro, outro, podcast description, and social copy instead of being replaced
  - full-pack generation now passes a truly empty current title to the model when the field is blank, so the assistant no longer treats `Episode 3` / chapter numbering as a locked title by mistake
  - full-pack title generation now explicitly forbids generic numbering-only titles and pushes for concise non-spoilery episode names grounded in the episode’s strongest image, object, place, or tension
  - intro/outro/podcast-description prompts are tighter and more spoiler-safe, with less license to invent details
  - podcast descriptions are now instructed to stay teaser-level and avoid second-half reveals, late discoveries, dream/vision content, ending-state consequences, and other recap-style spoilers
  - the old episode summary field is now labeled `Podcast Description` and is explicitly generated as TV-guide/show-notes style teaser copy rather than a plot summary
  - cover-art prompts are now instructed to re-check factual accuracy against episode text
  - character style guide cards now include visual descriptions for image/cover-art prompt generation
  - the episode prep drawer now follows the project editor font size so podcast drafting reads more like the main manuscript views
- Style Guide UI:
  - the project style guide sheet and character guide editors now follow the current manuscript editor font size instead of using smaller fixed text sizing
  - project style guide and character guide multiline editors now use a caret-following scrolling AppKit text view so keyboard navigation keeps the insertion point visible below the fold
- Find / Replace:
  - search and replace now understand escaped paragraph and tab markers
  - supported markers include `\n`, `\t`, `^p`, and `^t`
  - this makes it possible to find double paragraph breaks like `^p^p` and replace them with a single `^p`
  - Find / Replace now also has a `?` help popover listing the supported markers, plus writer-friendly examples for double paragraph breaks, em dashes, and double spaces
- Import/export groundwork:
  - project cards now offer `Export Backup…` for a full JSON backup package
  - project cards now offer named export presets instead of one generic manuscript/docx path:
    - `Export Standard Manuscript…` for readable plain-text manuscript export
    - `Export KDP Paperback DOCX…` for print-oriented chapter-page-break DOCX layout
    - `Export KDP Hardcover DOCX…` for KDP hardcover-oriented chapter-page-break DOCX layout
  - binder chapter/scene context menus now also offer plain-text export for the clicked scope, adapting to `Chapter`, `Scene`, or `Selected` depending on the current binder selection
  - binder context menus also offer `Export ... Using Audio Pronunciations…`, which applies the project's enabled audio pronunciation replacements during export without touching manuscript text
  - standard manuscript exports no longer inject preset metadata into the manuscript body
  - scene-heading visibility is now consistent between plain-text and DOCX exports: scene headings appear only when a chapter actually contains multiple scenes
  - KDP print presets now target the common 6" x 9" trim size with document-level page size and margin defaults derived from current KDP print guidance
  - KDP print export presets are implemented but still need real output testing in Word/Pages and against an actual KDP upload workflow
  - Projects screen now offers `Import DOCX`, creating a new project from a Word document
  - chapter headings are detected from imported `.docx` structure/text markers
  - chapters are split into scenes using explicit scene-break markers first, then paragraph-boundary word-count chunking as a fallback
  - `.docx` import is first-pass heuristic import, not final assistant-guided scene parsing yet
  - `.docx` import now falls back through macOS `textutil` when direct AppKit Word parsing fails
  - import failures now stay visible longer and include a more specific reason when available
  - imported rich text now gets the app’s native readable appearance instead of keeping tiny/dark Word styling on first render
  - assistant now has a chapter-level `Propose Scene Breaks` action that can draft scene starts for imported chapters, plus an `Apply Scene Breaks` action bar
- Multi-selection editing flow:
  - explicit combined multi-scene or multi-chapter selections now open in a continuous plain-text editor instead of separate scene cards
  - the continuous editor keeps scene labels outside the text area so cursor movement and drag selection can pass across scene boundaries
  - batch edits across that flowing block now write back to the underlying scenes in one pass
  - this first version is intentionally plain-text focused; editing in this mode clears rich-text styling for the affected scenes
- App-level create undo:
  - creating a chapter or scene now registers with the app undo banner, so immediately undoing a mistaken create removes that created item instead of relying on editor-text undo state
- App icon:
  - generated PNG set wired into `/Users/mikecarmel/Documents/XcodeProject/Novel Writer Native/Assets.xcassets/AppIcon.appiconset`
  - generator script lives at `/Users/mikecarmel/Documents/XcodeProject/Docs/generate_app_icon.swift`
  - current icon direction is a parchment page with an ink bottle and quill in the warm cream / terracotta / espresso project palette

## Best Next Development Steps

1. Podcast refinement polish
   - test the new episode-title flow in real use
   - keep tightening intro/outro/summary creativity boundaries from actual episode runs
   - consider whether character visual descriptions need a dedicated build flow like voice rules

2. Publishing/export presets
   - publisher-targeted presets such as Amazon KDP
   - richer manuscript export profiles beyond the current JSON / TXT / DOCX set

3. Sync follow-up polish
   - maybe add auto-reload or diff-aware reload prompts
   - consider a clearer “last loaded from disk” indicator
   - consider a small `Loaded rX / Disk rY` debug readout while cross-Mac testing

## Build Check

Use:

```bash
xcodebuild -project "/Users/mikecarmel/Documents/XcodeProject/Novel Writer Native.xcodeproj" -scheme "Novel Writer Native" -configuration Debug -derivedDataPath "/tmp/NovelWriterNativeDerivedData" build
```

Note:

- Building with derived data under `/Users/mikecarmel/Documents/XcodeProject/.derivedData` currently hits a codesign metadata issue because the project now lives under `Documents`.
- Using `/tmp/NovelWriterNativeDerivedData` is the current reliable build check path.

## Suggested Codex Resume Prompt

Use this in Codex on either Mac:

`Continue work on the native macOS app for Novel Writer. Project: /Users/mikecarmel/Documents/XcodeProject/Novel Writer Native.xcodeproj. Read /Users/mikecarmel/Documents/XcodeProject/Docs/DEV_HANDOFF.md first, then continue from the current state.`
