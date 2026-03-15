import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import type { JSONContent } from "@tiptap/core";
import { TextSelection } from "@tiptap/pm/state";
import { EditorContent, useEditor, type Editor } from "@tiptap/react";

import { InlineEditableText } from "../../components/InlineEditableText";
import { EMPTY_DOCUMENT, normalizeRichTextContent } from "../../lib/editorContent";
import type { ChapterRecord, ProjectRecord, SceneRecord } from "../../types/models";
import { FindReplacePanel } from "./FindReplacePanel";
import { EditorToolbar } from "./EditorToolbar";
import { editorExtensions } from "./editorExtensions";
import { SearchHighlightExtension } from "./searchHighlightExtension";
import type { SearchOptions } from "./searchUtils";
import {
  findMatchesInEditor,
  findMatchesInScenes,
  findSelectedText
} from "./searchUtils";

interface EditorShellProps {
  project: ProjectRecord;
  chapters: ChapterRecord[];
  scenes: SceneRecord[];
  scene: SceneRecord | null;
  selectedScenes: SceneRecord[];
  isCombinedSelection?: boolean;
  editorZoomPercent: number;
  onRenameScene: (title: string) => void;
  onUpdateSceneDraftLocal: (sceneId: string, contentJson: JSONContent) => void;
  onSaveSceneDraft: (sceneId: string, contentJson: JSONContent) => Promise<void>;
  onSaveSceneEditorState: (
    sceneId: string,
    cursorFrom: number | null,
    cursorTo: number | null,
    scrollTop: number
  ) => Promise<void>;
  onLoadSceneEditorState: (sceneId: string) => Promise<{
    cursorFrom: number | null;
    cursorTo: number | null;
    scrollTop: number;
  } | null>;
  onSetEditorZoom: (zoomPercent: number) => Promise<void>;
  focusSceneId?: string | null;
  onSceneFocusHandled?: (sceneId: string) => void;
  readOnly?: boolean;
  previewLabel?: string | null;
}

export function EditorShell(props: EditorShellProps) {
  const {
    project,
    chapters,
    scenes,
    scene,
    selectedScenes,
    isCombinedSelection = false,
    editorZoomPercent,
    onRenameScene,
    onUpdateSceneDraftLocal,
    onSaveSceneDraft,
    onSaveSceneEditorState,
    onLoadSceneEditorState,
    onSetEditorZoom,
    focusSceneId,
    onSceneFocusHandled,
    readOnly = false,
    previewLabel = null
  } = props;

  const orderedSelectedScenes = orderScenesForDisplay(chapters, selectedScenes);
  const [searchOptions, setSearchOptions] = useState<SearchOptions>({
    query: "",
    replaceText: "",
    scope: "selection",
    mode: "contains",
    ignoreCase: true,
    ignoreDiacritics: true
  });
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [searchResults, setSearchResults] = useState<ReturnType<typeof findMatchesInScenes>>([]);
  const [currentMatchIndex, setCurrentMatchIndex] = useState(0);
  const [replacedCount, setReplacedCount] = useState(0);
  const [copyNotice, setCopyNotice] = useState<string | null>(null);
  const [activeCompositeEditor, setActiveCompositeEditor] = useState<Editor | null>(null);
  const [isCompositeSelectAllActive, setIsCompositeSelectAllActive] = useState(false);
  const [isAtlasViewOpen, setIsAtlasViewOpen] = useState(false);
  const activeCompositeEditorRef = useRef<Editor | null>(null);
  const preferredVerticalXRef = useRef<number | null>(null);
  const rootRef = useRef<HTMLElement | null>(null);
  const atlasTextareaRef = useRef<HTMLTextAreaElement | null>(null);
  const editorRegistryRef = useRef(new Map<string, Editor>());
  const sceneBlockRefs = useRef<Record<string, HTMLDivElement | null>>({});
  const searchDebounceRef = useRef<number | null>(null);
  const orderedProjectScenes = useMemo(() => orderScenesForDisplay(chapters, scenes), [chapters, scenes]);
  const searchScopeScenes = searchOptions.scope === "entire_project"
    ? orderedProjectScenes
    : orderedSelectedScenes;
  const displayScenes = isSearchOpen && searchOptions.scope === "entire_project"
    ? orderedProjectScenes
    : orderedSelectedScenes;
  const isCompositeMode = displayScenes.length > 1;
  const isEmptyEditorState = !scene && displayScenes.length === 0;
  const totalSelectedWordCount = searchScopeScenes.reduce((sum, item) => sum + item.wordCount, 0);
  const totalSelectedCharacterCount = searchScopeScenes.reduce((sum, item) => sum + item.characterCount, 0);
  const displaySceneIdsKey = displayScenes.map((entry) => entry.id).join("|");
  const atlasScopeScenes = displayScenes.length > 0 ? displayScenes : scene ? [scene] : [];
  const atlasSnapshot = useMemo(
    () => buildScopeSnapshot(project, chapters, atlasScopeScenes),
    [atlasScopeScenes, chapters, project]
  );

  useEffect(() => {
    setIsCompositeSelectAllActive(false);
  }, [displaySceneIdsKey]);

  useEffect(() => {
    if (!isAtlasViewOpen) {
      return;
    }

    const timeoutId = window.setTimeout(() => {
      atlasTextareaRef.current?.focus();
      atlasTextareaRef.current?.setSelectionRange(0, atlasSnapshot.length);
    }, 0);

    return () => {
      window.clearTimeout(timeoutId);
    };
  }, [atlasSnapshot, isAtlasViewOpen]);

  useEffect(() => {
    if (!copyNotice) {
      return;
    }

    const timeoutId = window.setTimeout(() => {
      setCopyNotice(null);
    }, 2200);

    return () => {
      window.clearTimeout(timeoutId);
    };
  }, [copyNotice]);

  useEffect(() => {
    if (!isSearchOpen) {
      setSearchResults([]);
      setCurrentMatchIndex(0);
      setReplacedCount(0);

      for (const editor of editorRegistryRef.current.values()) {
        editor.commands.clearSearchHighlights();
      }

      return;
    }

    if (searchDebounceRef.current) {
      window.clearTimeout(searchDebounceRef.current);
    }

    searchDebounceRef.current = window.setTimeout(() => {
      const nextResults = findMatchesInScenes(searchScopeScenes, searchOptions);
      setSearchResults(nextResults);
      setCurrentMatchIndex((current) => {
        if (nextResults.length === 0) {
          return 0;
        }

        return Math.min(current, nextResults.length - 1);
      });
    }, 250);

    return () => {
      if (searchDebounceRef.current) {
        window.clearTimeout(searchDebounceRef.current);
      }
    };
  }, [isSearchOpen, searchOptions, searchScopeScenes]);

  useEffect(() => {
    if (!isSearchOpen) {
      return;
    }

    const currentMatch = searchResults[currentMatchIndex] ?? null;

    for (const [sceneId, editor] of editorRegistryRef.current.entries()) {
      const localMatches = findMatchesInEditor(editor, sceneId, searchOptions);
      const activeLocalIndex = currentMatch?.sceneId === sceneId
        ? localMatches.findIndex((match) => match.ordinal === currentMatch.ordinal)
        : null;

      editor.commands.setSearchHighlights(
        localMatches.map((match) => ({ from: match.from, to: match.to })),
        activeLocalIndex === -1 ? null : activeLocalIndex
      );
    }
  }, [currentMatchIndex, isSearchOpen, searchOptions, searchResults]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      const activeElement = document.activeElement;
      const isFocusInsideWorkspace =
        (target instanceof Element && Boolean(target.closest(".workspace-shell"))) ||
        (activeElement instanceof Element && Boolean(activeElement.closest(".workspace-shell")));
      const isFocusInsideEditorShell =
        (target instanceof Element && Boolean(target.closest(".editor-shell"))) ||
        (activeElement instanceof Element && Boolean(activeElement.closest(".editor-shell")));
      const isFindShortcut = (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "f";
      const isSelectAllShortcut = (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "a";
      const isCopyScopeShortcut = (event.metaKey || event.ctrlKey) && event.shiftKey && event.key.toLowerCase() === "c";
      if (isFindShortcut && isFocusInsideWorkspace) {
        event.preventDefault();
        event.stopPropagation();
        const selectedText = findSelectedText(activeCompositeEditor);
        setSearchOptions((current) => ({
          ...current,
          query: selectedText
        }));
        setIsSearchOpen(true);
        return;
      }

      if (isSelectAllShortcut && isCompositeMode && isFocusInsideEditorShell) {
        event.preventDefault();
        event.stopPropagation();
        setIsCompositeSelectAllActive(true);
        return;
      }

      if (isCopyScopeShortcut && isFocusInsideEditorShell) {
        event.preventDefault();
        event.stopPropagation();
        void copyCurrentScope();
        return;
      }

      if (event.key === "Escape" && isSearchOpen) {
        event.preventDefault();
        setIsSearchOpen(false);
        setIsCompositeSelectAllActive(false);
        return;
      }

      if (event.key === "Escape" && isAtlasViewOpen) {
        event.preventDefault();
        setIsAtlasViewOpen(false);
        return;
      }

      if (event.key === "Escape" && isCompositeSelectAllActive) {
        event.preventDefault();
        setIsCompositeSelectAllActive(false);
      }
    };

    document.addEventListener("keydown", handleKeyDown, true);
    return () => {
      document.removeEventListener("keydown", handleKeyDown, true);
    };
  }, [activeCompositeEditor, isAtlasViewOpen, isCompositeMode, isCompositeSelectAllActive, isSearchOpen, scene, displayScenes, project, chapters]);

  useEffect(() => {
    if (!isCompositeSelectAllActive) {
      return;
    }

    const frameId = window.requestAnimationFrame(() => {
      selectAllCompositeText(rootRef.current);
    });

    const handlePointerDown = (event: MouseEvent) => {
      const target = event.target as Node | null;
      if (target && rootRef.current?.contains(target)) {
        setIsCompositeSelectAllActive(false);
      }
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      const isModifier = ["Meta", "Control", "Shift", "Alt"].includes(event.key);
      const isCopyShortcut = (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "c";
      const isSelectAllShortcut = (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "a";
      if (isModifier || isCopyShortcut || isSelectAllShortcut) {
        return;
      }

      setIsCompositeSelectAllActive(false);
    };

    document.addEventListener("mousedown", handlePointerDown, true);
    document.addEventListener("keydown", handleKeyDown, true);

    return () => {
      window.cancelAnimationFrame(frameId);
      document.removeEventListener("mousedown", handlePointerDown, true);
      document.removeEventListener("keydown", handleKeyDown, true);
    };
  }, [isCompositeSelectAllActive]);

  useEffect(() => {
    const handleCopy = (event: ClipboardEvent) => {
      const activeElement = document.activeElement;
      const isFocusInsideEditorShell =
        activeElement instanceof Element &&
        Boolean(activeElement.closest(".editor-shell"));
      if (!isCompositeSelectAllActive || !isCompositeMode || !isFocusInsideEditorShell) {
        return;
      }

      const combinedHtml = displayScenes
        .map((selectedScene) => editorRegistryRef.current.get(selectedScene.id)?.getHTML() ?? "")
        .filter(Boolean)
        .join("<hr data-composite-scene-break=\"true\" />");
      const combinedText = displayScenes
        .map((selectedScene) => editorRegistryRef.current.get(selectedScene.id)?.getText() ?? selectedScene.contentText)
        .join("\n\n");

      event.preventDefault();
      event.clipboardData?.setData("text/plain", combinedText);
      if (combinedHtml) {
        event.clipboardData?.setData("text/html", combinedHtml);
      }
    };

    document.addEventListener("copy", handleCopy, true);
    return () => {
      document.removeEventListener("copy", handleCopy, true);
    };
  }, [displayScenes, isCompositeMode, isCompositeSelectAllActive]);

  function handleOptionsChange(patch: Partial<SearchOptions>) {
    setSearchOptions((current) => ({
      ...current,
      ...patch
    }));
    setCurrentMatchIndex(0);
  }

  function setCompositeEditor(editor: Editor | null) {
    if (!editor) {
      return;
    }

    activeCompositeEditorRef.current = editor;
    setActiveCompositeEditor(editor);
  }

  function setPreferredVerticalX(nextX: number | null | undefined) {
    if (nextX == null || Number.isNaN(nextX)) {
      return;
    }

    preferredVerticalXRef.current = nextX;
  }

  function focusMatch(matchIndex: number) {
    const match = searchResults[matchIndex];
    if (!match) {
      return;
    }

    const editor = editorRegistryRef.current.get(match.sceneId);
    if (!editor) {
      return;
    }

    const localMatch = findMatchesInEditor(editor, match.sceneId, searchOptions)
      .find((entry) => entry.ordinal === match.ordinal);
    if (!localMatch) {
      return;
    }

    sceneBlockRefs.current[match.sceneId]?.scrollIntoView({
      block: "center",
      behavior: "smooth"
    });
    editor.chain().focus().setTextSelection({ from: localMatch.from, to: localMatch.to }).scrollIntoView().run();
    setActiveCompositeEditor(editor);
    setCurrentMatchIndex(matchIndex);
  }

  async function copyCurrentScope() {
    if (!atlasSnapshot) {
      return;
    }

    try {
      await navigator.clipboard.writeText(atlasSnapshot);
      setCopyNotice(`Copied ${atlasScopeScenes.length > 1 ? `${atlasScopeScenes.length} scenes` : "current scene"} for Atlas`);
      setIsCompositeSelectAllActive(false);
    } catch {
      setCopyNotice("Copy failed. Try again.");
    }
  }

  function handleOpenAtlasView() {
    if (!atlasSnapshot) {
      return;
    }

    setIsAtlasViewOpen(true);
    setCopyNotice("Atlas view opened");
    setIsCompositeSelectAllActive(false);
  }

  function handleSelectAllAtlasView() {
    atlasTextareaRef.current?.focus();
    atlasTextareaRef.current?.setSelectionRange(0, atlasSnapshot.length);
  }

  function renderAtlasViewOverlay() {
    if (!isAtlasViewOpen) {
      return null;
    }

    return (
      <div className="atlas-view-backdrop" role="dialog" aria-modal="true" aria-label="Atlas View">
        <div className="atlas-view-panel">
          <div className="atlas-view-header">
            <div>
              <p className="section-label">Atlas View</p>
              <h3>
                {atlasScopeScenes.length > 1
                  ? `${atlasScopeScenes.length} scenes as one continuous document`
                  : "Current scene as one continuous document"}
              </h3>
            </div>
            <div className="atlas-view-actions">
              <button
                type="button"
                className="secondary-button"
                onClick={handleSelectAllAtlasView}
              >
                Select all
              </button>
              <button
                type="button"
                className="secondary-button"
                onClick={() => {
                  void copyCurrentScope();
                }}
              >
                Copy scope
              </button>
              <button
                type="button"
                className="primary-button"
                onClick={() => setIsAtlasViewOpen(false)}
              >
                Close
              </button>
            </div>
          </div>

          <p className="atlas-view-note">
            This view flattens your current binder selection into one read-only surface so Atlas can see it as one document.
          </p>

          <textarea
            ref={atlasTextareaRef}
            className="atlas-view-textarea"
            value={atlasSnapshot}
            readOnly
            spellCheck={false}
          />
        </div>
      </div>
    );
  }

  function handleNextMatch() {
    if (searchResults.length === 0) {
      return;
    }

    const nextIndex = (currentMatchIndex + 1) % searchResults.length;
    focusMatch(nextIndex);
  }

  function handlePreviousMatch() {
    if (searchResults.length === 0) {
      return;
    }

    const nextIndex = (currentMatchIndex - 1 + searchResults.length) % searchResults.length;
    focusMatch(nextIndex);
  }

  function replaceCurrentMatch() {
    if (readOnly) {
      return false;
    }

    const currentMatch = searchResults[currentMatchIndex];
    if (!currentMatch) {
      return false;
    }

    const editor = editorRegistryRef.current.get(currentMatch.sceneId);
    if (!editor) {
      return false;
    }

    const localMatch = findMatchesInEditor(editor, currentMatch.sceneId, searchOptions)
      .find((entry) => entry.ordinal === currentMatch.ordinal);
    if (!localMatch) {
      return false;
    }

    editor.chain().focus().setTextSelection({ from: localMatch.from, to: localMatch.to }).insertContent(searchOptions.replaceText).run();
    setReplacedCount((count) => count + 1);
    return true;
  }

  function handleReplaceAndFind() {
    if (replaceCurrentMatch()) {
      window.setTimeout(() => {
        handleNextMatch();
      }, 0);
    }
  }

  function handleReplaceAll() {
    if (readOnly) {
      return;
    }

    let replacements = 0;

    for (const scopedScene of searchScopeScenes) {
      const editor = editorRegistryRef.current.get(scopedScene.id);
      if (!editor) {
        continue;
      }

      const localMatches = findMatchesInEditor(editor, scopedScene.id, searchOptions).reverse();
      for (const match of localMatches) {
        editor.chain().focus().setTextSelection({ from: match.from, to: match.to }).insertContent(searchOptions.replaceText).run();
        replacements += 1;
      }
    }

    setReplacedCount((count) => count + replacements);
  }

  function handleCompositeBoundaryNavigate(
    direction: "previous" | "next",
    currentSceneId: string,
    preferredX?: number
  ) {
    setPreferredVerticalX(preferredX);
    const currentIndex = displayScenes.findIndex((entry) => entry.id === currentSceneId);
    if (currentIndex === -1) {
      return false;
    }

    const targetIndex = direction === "next" ? currentIndex + 1 : currentIndex - 1;
    const targetScene = displayScenes[targetIndex];
    if (!targetScene) {
      return false;
    }

    const targetEditor = editorRegistryRef.current.get(targetScene.id);
    if (!targetEditor) {
      return false;
    }

    sceneBlockRefs.current[targetScene.id]?.scrollIntoView({
      block: "nearest",
      behavior: "smooth"
    });

    const targetView = targetEditor.view;
    const targetSelection = direction === "next"
      ? resolveVerticalSceneSelection(targetView, "start", preferredVerticalXRef.current)
      : resolveVerticalSceneSelection(targetView, "end", preferredVerticalXRef.current);

    targetEditor.commands.focus();
    targetView.dispatch(
      targetView.state.tr.setSelection(targetSelection).scrollIntoView()
    );
    setCompositeEditor(targetEditor);
    return true;
  }

  if (isEmptyEditorState) {
    return (
      <section className="editor-shell empty-editor">
        <p className="section-label">Milestone 3</p>
        <h2>Select a scene</h2>
        <p>Choose an existing scene or create a new one under the currently selected chapter.</p>
      </section>
    );
  }

  if (isCompositeMode) {
    return (
      <section ref={rootRef} className="editor-shell">
        <FindReplacePanel
          isOpen={isSearchOpen}
          options={searchOptions}
          foundCount={searchResults.length}
          currentMatchNumber={searchResults.length === 0 ? 0 : currentMatchIndex + 1}
          replacedCount={replacedCount}
          onClose={() => setIsSearchOpen(false)}
          onOptionsChange={handleOptionsChange}
          onNext={handleNextMatch}
          onPrevious={handlePreviousMatch}
          onReplace={() => {
            void replaceCurrentMatch();
          }}
          onReplaceAndFind={handleReplaceAndFind}
          onReplaceAll={handleReplaceAll}
        />
        <div className="editor-header">
          <div>
            <p className="section-label">{project.title}</p>
            <h2 className="editor-composite-title">Composite Editor</h2>
          </div>
          <div className="editor-metrics">
            <span>{isCombinedSelection ? "Combined" : "Chapter"}: {totalSelectedWordCount.toLocaleString()}</span>
            <span>Characters: {totalSelectedCharacterCount.toLocaleString()}</span>
          </div>
        </div>

        <div className={`composite-notice ${isCompositeSelectAllActive ? "is-select-all" : ""}`}>
          <ContinuousWritingIcon />
          <span>
            {readOnly
              ? previewLabel ?? "Trash Preview"
              : copyNotice
                ? copyNotice
                : isCompositeSelectAllActive
                ? `All ${orderedSelectedScenes.length} scenes selected for copy`
                : `Editing ${orderedSelectedScenes.length} scenes`}
          </span>
        </div>

        {readOnly ? (
          <div className="trash-preview-banner">
            <strong>Trash Preview</strong>
            <span>Read-only preview. Restore the item from Trash to edit it again.</span>
          </div>
        ) : null}

        <EditorToolbar
          editor={activeCompositeEditor}
          zoomPercent={editorZoomPercent}
          onZoomChange={(zoomPercent) => void onSetEditorZoom(zoomPercent)}
          onOpenAtlasView={handleOpenAtlasView}
          onCopyCurrentScope={() => {
            void copyCurrentScope();
          }}
          isDisabled={readOnly || isCompositeSelectAllActive}
        />

        <div className="editor-surface">
          <div className="editor-scroll-shell composite-scroll-shell">
            <div
              className="editor-writing-column composite-writing-column"
              data-composite-select-all={isCompositeSelectAllActive ? "true" : "false"}
              style={
                {
                  "--editor-zoom-scale": `${editorZoomPercent / 100}`
                } as CSSProperties
              }
            >
              {displayScenes.map((selectedScene, index) => {
                const chapter = chapters.find((entry) => entry.id === selectedScene.chapterId) ?? null;

                return (
                  <div
                    key={selectedScene.id}
                    ref={(element) => {
                      sceneBlockRefs.current[selectedScene.id] = element;
                    }}
                    className="composite-scene-block"
                  >
                    <div className="scene-divider" contentEditable={false}>
                      {"\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500 "}
                      {chapter?.title ?? "Chapter"} · {selectedScene.title}
                      {" \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500"}
                    </div>

                    <RichSceneEditor
                      scene={selectedScene}
                      editorZoomPercent={editorZoomPercent}
                      onUpdateSceneDraftLocal={onUpdateSceneDraftLocal}
                      onSaveSceneDraft={onSaveSceneDraft}
                      onSaveSceneEditorState={onSaveSceneEditorState}
                      onLoadSceneEditorState={onLoadSceneEditorState}
                      onSetEditorZoom={onSetEditorZoom}
                      showToolbar={false}
                      isEmbedded
                      readOnly={readOnly || isCompositeSelectAllActive}
                      onCompositeSelectAll={() => {
                        setIsCompositeSelectAllActive(true);
                        return true;
                      }}
                      autoFocusAtStart={index === 0}
                      onEditorFocus={(editor, sceneId) => {
                        setCompositeEditor(editor);
                      }}
                      onBoundaryNavigate={handleCompositeBoundaryNavigate}
                      onPreferredVerticalXChange={setPreferredVerticalX}
                      onEditorReady={(sceneId, editor) => {
                        if (editor) {
                          editorRegistryRef.current.set(sceneId, editor);
                          if (!activeCompositeEditorRef.current) {
                            setCompositeEditor(editor);
                          }
                        } else {
                          editorRegistryRef.current.delete(sceneId);
                        }
                      }}
                    />
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {renderAtlasViewOverlay()}
      </section>
    );
  }

  if (!scene) {
    return null;
  }

  const chapterWordCount = scenes
    .filter((entry) => entry.chapterId === scene.chapterId)
    .reduce((total, entry) => total + entry.wordCount, 0);
  const activeChapter = chapters.find((chapter) => chapter.id === scene.chapterId) ?? null;

  return (
    <section ref={rootRef} className="editor-shell">
      <FindReplacePanel
        isOpen={isSearchOpen}
        options={searchOptions}
        foundCount={searchResults.length}
        currentMatchNumber={searchResults.length === 0 ? 0 : currentMatchIndex + 1}
        replacedCount={replacedCount}
        onClose={() => setIsSearchOpen(false)}
        onOptionsChange={handleOptionsChange}
        onNext={handleNextMatch}
        onPrevious={handlePreviousMatch}
        onReplace={() => {
          void replaceCurrentMatch();
        }}
        onReplaceAndFind={handleReplaceAndFind}
        onReplaceAll={handleReplaceAll}
      />
      <div className="editor-header">
        <div>
          <p className="section-label">{project.title}</p>
          <p className="editor-subtitle editor-chapter-title">{activeChapter?.title ?? "Chapter"}</p>
          {readOnly ? (
            <h2 className="editor-title-input editor-title-static">{scene.title}</h2>
          ) : (
            <InlineEditableText
              className="editor-title-input"
              value={scene.title}
              onCommit={onRenameScene}
            />
          )}
        </div>
        <div className="editor-metrics">
          <span>Scene: {scene.wordCount.toLocaleString()}</span>
          <span>Characters: {scene.characterCount.toLocaleString()}</span>
          <span>Chapter: {chapterWordCount.toLocaleString()}</span>
        </div>
      </div>

      {scene.conflictState !== "none" ? (
        <div className={`conflict-notice is-${scene.conflictState}`}>
          <strong>{scene.conflictState === "local" ? "Local conflict copy" : "Remote conflict copy"}</strong>
          <span>
            {scene.conflictState === "local"
              ? "Your local version was preserved because a newer remote scene also exists."
              : "This is the preserved remote version. Your original local scene was kept separately."}
          </span>
          {scene.conflictGroupId ? <span>Conflict group: {scene.conflictGroupId}</span> : null}
        </div>
      ) : null}

      {readOnly ? (
        <div className="trash-preview-banner">
          <strong>Trash Preview</strong>
          <span>{previewLabel ?? "Read-only preview. Restore the item from Trash to edit it again."}</span>
        </div>
      ) : null}

      {copyNotice ? (
        <div className="composite-notice is-select-all">
          <ContinuousWritingIcon />
          <span>{copyNotice}</span>
        </div>
      ) : null}

      <EditorToolbar
        editor={activeCompositeEditor}
        zoomPercent={editorZoomPercent}
        onZoomChange={(zoomPercent) => void onSetEditorZoom(zoomPercent)}
        onOpenAtlasView={handleOpenAtlasView}
        onCopyCurrentScope={() => {
          void copyCurrentScope();
        }}
        isDisabled={readOnly}
      />

      <RichSceneEditor
        key={scene.id}
        scene={scene}
        editorZoomPercent={editorZoomPercent}
        onUpdateSceneDraftLocal={onUpdateSceneDraftLocal}
        onSaveSceneDraft={onSaveSceneDraft}
        onSaveSceneEditorState={onSaveSceneEditorState}
        onLoadSceneEditorState={onLoadSceneEditorState}
        onSetEditorZoom={onSetEditorZoom}
        showToolbar={false}
        readOnly={readOnly}
        forceFocusOnMount={focusSceneId === scene.id}
        onAutoFocusApplied={onSceneFocusHandled}
        onEditorFocus={(editor, sceneId) => {
          setActiveCompositeEditor(editor);
        }}
        onPreferredVerticalXChange={setPreferredVerticalX}
        onEditorReady={(sceneId, editor) => {
          if (editor) {
            editorRegistryRef.current.set(sceneId, editor);
            setActiveCompositeEditor(editor);
          } else {
            editorRegistryRef.current.delete(sceneId);
          }
        }}
      />

      {renderAtlasViewOverlay()}
    </section>
  );
}

interface RichSceneEditorProps {
  scene: SceneRecord;
  editorZoomPercent: number;
  onUpdateSceneDraftLocal: (sceneId: string, contentJson: JSONContent) => void;
  onSaveSceneDraft: (sceneId: string, contentJson: JSONContent) => Promise<void>;
  onSaveSceneEditorState: (
    sceneId: string,
    cursorFrom: number | null,
    cursorTo: number | null,
    scrollTop: number
  ) => Promise<void>;
  onLoadSceneEditorState: (sceneId: string) => Promise<{
    cursorFrom: number | null;
    cursorTo: number | null;
    scrollTop: number;
  } | null>;
  onSetEditorZoom: (zoomPercent: number) => Promise<void>;
  onEditorFocus?: (editor: Editor | null, sceneId: string) => void;
  onEditorReady?: (sceneId: string, editor: Editor | null) => void;
  onBoundaryNavigate?: (
    direction: "previous" | "next",
    currentSceneId: string,
    preferredX?: number
  ) => boolean;
  onCompositeSelectAll?: () => boolean;
  onPreferredVerticalXChange?: (nextX: number | null | undefined) => void;
  forceFocusOnMount?: boolean;
  onAutoFocusApplied?: (sceneId: string) => void;
  showToolbar?: boolean;
  isEmbedded?: boolean;
  autoFocusAtStart?: boolean;
  readOnly?: boolean;
}

function RichSceneEditor({
  scene,
  editorZoomPercent,
  onUpdateSceneDraftLocal,
  onSaveSceneDraft,
  onSaveSceneEditorState,
  onLoadSceneEditorState,
  onSetEditorZoom,
  onEditorFocus,
  onEditorReady,
  onBoundaryNavigate,
  onCompositeSelectAll,
  onPreferredVerticalXChange,
  forceFocusOnMount = false,
  onAutoFocusApplied,
  showToolbar = true,
  isEmbedded = false,
  autoFocusAtStart = false,
  readOnly = false
}: RichSceneEditorProps) {
  const scrollContainerRef = useRef<HTMLDivElement | null>(null);
  const saveTimeoutRef = useRef<number | null>(null);
  const editorStateTimeoutRef = useRef<number | null>(null);
  const latestSceneIdRef = useRef(scene.id);
  const latestSaveSceneDraftRef = useRef(onSaveSceneDraft);
  const latestSaveSceneEditorStateRef = useRef(onSaveSceneEditorState);
  const latestLoadSceneEditorStateRef = useRef(onLoadSceneEditorState);
  const latestUpdateSceneDraftLocalRef = useRef(onUpdateSceneDraftLocal);
  const latestOnEditorFocusRef = useRef(onEditorFocus);
  const latestOnEditorReadyRef = useRef(onEditorReady);
  const latestOnAutoFocusAppliedRef = useRef(onAutoFocusApplied);
  const latestDocumentRef = useRef<JSONContent>(
    (normalizeRichTextContent(scene) as JSONContent) ?? (EMPTY_DOCUMENT as JSONContent)
  );
  const [isRestoring, setIsRestoring] = useState(true);

  useEffect(() => {
    latestSceneIdRef.current = scene.id;
    latestSaveSceneDraftRef.current = onSaveSceneDraft;
    latestSaveSceneEditorStateRef.current = onSaveSceneEditorState;
    latestLoadSceneEditorStateRef.current = onLoadSceneEditorState;
    latestUpdateSceneDraftLocalRef.current = onUpdateSceneDraftLocal;
    latestOnEditorFocusRef.current = onEditorFocus;
    latestOnEditorReadyRef.current = onEditorReady;
    latestOnAutoFocusAppliedRef.current = onAutoFocusApplied;
  }, [
    onLoadSceneEditorState,
    onAutoFocusApplied,
    onEditorFocus,
    onEditorReady,
    onSaveSceneDraft,
    onSaveSceneEditorState,
    onUpdateSceneDraftLocal,
    scene.id
  ]);

  useEffect(() => {
    latestDocumentRef.current =
      (normalizeRichTextContent(scene) as JSONContent) ?? (EMPTY_DOCUMENT as JSONContent);
    setIsRestoring(true);
  }, [scene.id]);

  const editor = useEditor({
    extensions: [...editorExtensions, SearchHighlightExtension],
    content: latestDocumentRef.current,
    autofocus: false,
    editable: !readOnly,
    editorProps: {
      attributes: {
        class: `novel-editor-content ${isEmbedded ? "is-embedded" : ""}`,
        dir: "ltr"
      },
      handleKeyDown: (view, event) => {
        if (isEmbedded && (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "a") {
          const didHandle = onCompositeSelectAll?.() ?? false;
          if (didHandle) {
            event.preventDefault();
            return true;
          }
        }

        if (!isEmbedded || !onBoundaryNavigate) {
          return false;
        }

        const { selection, doc } = view.state;
        if (!selection.empty) {
          return false;
        }

        const startSelection = TextSelection.atStart(doc);
        const endSelection = TextSelection.atEnd(doc);
        const caretX = (() => {
          try {
            return view.coordsAtPos(selection.from).left;
          } catch {
            return undefined;
          }
        })();
        const isArrowUpOnFirstVisualLine = (() => {
          if (event.key !== "ArrowUp") {
            return false;
          }

          try {
            const caretCoords = view.coordsAtPos(selection.from);
            const startCoords = view.coordsAtPos(startSelection.from);
            return Math.abs(caretCoords.top - startCoords.top) <= 4;
          } catch {
            return false;
          }
        })();
        const isArrowDownOnLastVisualLine = (() => {
          if (event.key !== "ArrowDown") {
            return false;
          }

          try {
            const caretCoords = view.coordsAtPos(selection.from);
            const endCoords = view.coordsAtPos(endSelection.from);
            return Math.abs(caretCoords.top - endCoords.top) <= 4;
          } catch {
            return false;
          }
        })();
        const isAtVisualStart =
          (event.key === "ArrowUp" && isArrowUpOnFirstVisualLine) ||
          (
            selection.from === startSelection.from &&
            selection.to === startSelection.to &&
            event.key === "ArrowLeft" &&
            view.endOfTextblock("left")
          );
        const isAtVisualEnd =
          (event.key === "ArrowDown" && isArrowDownOnLastVisualLine) ||
          (
            selection.from === endSelection.from &&
            selection.to === endSelection.to &&
            event.key === "ArrowRight" &&
            view.endOfTextblock("right")
          );

        if (isAtVisualStart) {
          const didNavigate = onBoundaryNavigate("previous", scene.id, caretX);
          if (didNavigate) {
            event.preventDefault();
            return true;
          }
        }

        if (isAtVisualEnd) {
          const didNavigate = onBoundaryNavigate("next", scene.id, caretX);
          if (didNavigate) {
            event.preventDefault();
            return true;
          }
        }

        return false;
      }
    },
    onUpdate: ({ editor: currentEditor }) => {
      if (readOnly) {
        return;
      }
      const contentJson = currentEditor.getJSON();
      latestDocumentRef.current = contentJson;
      latestUpdateSceneDraftLocalRef.current(latestSceneIdRef.current, contentJson);
      scheduleSave(contentJson);
    },
    onSelectionUpdate: ({ editor: currentEditor }) => {
      try {
        onPreferredVerticalXChange?.(
          currentEditor.view.coordsAtPos(currentEditor.state.selection.from).left
        );
      } catch {
        onPreferredVerticalXChange?.(null);
      }
      if (!readOnly) {
        scheduleEditorStateSave(
          currentEditor.state.selection.from,
          currentEditor.state.selection.to,
          scrollContainerRef.current?.scrollTop ?? 0
        );
      }
    },
    onBlur: ({ editor: currentEditor }) => {
      if (readOnly) {
        return;
      }
      void flushSave(currentEditor.getJSON());
      void latestSaveSceneEditorStateRef.current(
        latestSceneIdRef.current,
        currentEditor.state.selection.from,
        currentEditor.state.selection.to,
        scrollContainerRef.current?.scrollTop ?? 0
      );
    }
  }, [readOnly, scene.id]);

  useEffect(() => {
    if (!editor) {
      return;
    }

    latestOnEditorReadyRef.current?.(scene.id, editor);
    const handleFocus = () => {
      latestOnEditorFocusRef.current?.(editor, scene.id);
    };

    editor.on("focus", handleFocus);

    return () => {
      editor.off("focus", handleFocus);
      latestOnEditorFocusRef.current?.(null, scene.id);
      latestOnEditorReadyRef.current?.(scene.id, null);
    };
  }, [editor, scene.id]);

  function clearSaveTimer() {
    if (saveTimeoutRef.current) {
      window.clearTimeout(saveTimeoutRef.current);
      saveTimeoutRef.current = null;
    }
  }

  function clearEditorStateTimer() {
    if (editorStateTimeoutRef.current) {
      window.clearTimeout(editorStateTimeoutRef.current);
      editorStateTimeoutRef.current = null;
    }
  }

  function scheduleSave(contentJson: JSONContent) {
    clearSaveTimer();
    saveTimeoutRef.current = window.setTimeout(() => {
      void flushSave(contentJson);
    }, 600);
  }

  function scheduleEditorStateSave(
    cursorFrom: number | null,
    cursorTo: number | null,
    scrollTop: number
  ) {
    clearEditorStateTimer();
    editorStateTimeoutRef.current = window.setTimeout(() => {
      void latestSaveSceneEditorStateRef.current(
        latestSceneIdRef.current,
        cursorFrom,
        cursorTo,
        scrollTop
      );
    }, 250);
  }

  async function flushSave(contentJson?: JSONContent) {
    clearSaveTimer();
    await latestSaveSceneDraftRef.current(
      latestSceneIdRef.current,
      contentJson ?? latestDocumentRef.current
    );
  }

  useEffect(() => {
    let isDisposed = false;

    async function restoreEditorState() {
      if (!editor) {
        return;
      }

      const session = await latestLoadSceneEditorStateRef.current(scene.id);
      if (isDisposed) {
        return;
      }

      requestAnimationFrame(() => {
        if (!editor || isDisposed) {
          return;
        }

        if (readOnly) {
          if (scrollContainerRef.current) {
            scrollContainerRef.current.scrollTop = 0;
          }
          setIsRestoring(false);
          return;
        }

        if (autoFocusAtStart) {
          editor.commands.focus("start");
          if (scrollContainerRef.current) {
            scrollContainerRef.current.scrollTop = 0;
          }
          setIsRestoring(false);
          return;
        }

        if (session) {
          const maxPosition = Math.max(1, editor.state.doc.content.size);
          const nextFrom = Math.max(1, Math.min(session.cursorFrom ?? 1, maxPosition));
          const nextTo = Math.max(nextFrom, Math.min(session.cursorTo ?? nextFrom, maxPosition));
          editor.commands.setTextSelection({ from: nextFrom, to: nextTo });
        }

        if (scrollContainerRef.current) {
          scrollContainerRef.current.scrollTop = session?.scrollTop ?? 0;
        }

        if (forceFocusOnMount) {
          editor.commands.focus();
          latestOnAutoFocusAppliedRef.current?.(scene.id);
        }

        setIsRestoring(false);
      });
    }

    void restoreEditorState();

    return () => {
      isDisposed = true;
    };
  }, [autoFocusAtStart, editor, forceFocusOnMount, readOnly, scene.id]);

  useEffect(() => {
    const scrollContainer = scrollContainerRef.current;
    if (!scrollContainer || !editor) {
      return;
    }

    const handleScroll = () => {
      if (readOnly) {
        return;
      }
      scheduleEditorStateSave(
        editor.state.selection.from,
        editor.state.selection.to,
        scrollContainer.scrollTop
      );
    };

    scrollContainer.addEventListener("scroll", handleScroll);
    return () => {
      scrollContainer.removeEventListener("scroll", handleScroll);
    };
  }, [editor, readOnly]);

  useEffect(() => {
    const handlePageHide = () => {
      if (readOnly) {
        return;
      }
      void flushSave();
      if (editor) {
        void latestSaveSceneEditorStateRef.current(
          latestSceneIdRef.current,
          editor.state.selection.from,
          editor.state.selection.to,
          scrollContainerRef.current?.scrollTop ?? 0
        );
      }
    };

    window.addEventListener("pagehide", handlePageHide);
    window.addEventListener("beforeunload", handlePageHide);

    return () => {
      window.removeEventListener("pagehide", handlePageHide);
      window.removeEventListener("beforeunload", handlePageHide);
      clearSaveTimer();
      clearEditorStateTimer();
    };
  }, [editor, readOnly]);

  return (
    <>
      {showToolbar ? (
        <EditorToolbar
          editor={editor}
          zoomPercent={editorZoomPercent}
          onZoomChange={(zoomPercent) => void onSetEditorZoom(zoomPercent)}
          isDisabled={readOnly}
        />
      ) : null}

      <div className={`editor-surface ${isEmbedded ? "is-embedded" : ""}`}>
        <div
          ref={scrollContainerRef}
          className={`editor-scroll-shell ${isRestoring ? "is-restoring" : ""} ${isEmbedded ? "is-embedded" : ""}`}
        >
          <div
            className={`editor-writing-column ${isEmbedded ? "is-embedded" : ""}`}
            style={
              {
                "--editor-zoom-scale": `${editorZoomPercent / 100}`
              } as CSSProperties
            }
          >
            <EditorContent editor={editor} />
          </div>
        </div>
      </div>
    </>
  );
}

function orderScenesForDisplay(
  chapters: ChapterRecord[],
  scenes: SceneRecord[]
): SceneRecord[] {
  const chapterOrder = new Map(chapters.map((chapter, index) => [chapter.id, index]));

  return [...scenes].sort((left, right) => {
    const leftChapterOrder = chapterOrder.get(left.chapterId) ?? Number.MAX_SAFE_INTEGER;
    const rightChapterOrder = chapterOrder.get(right.chapterId) ?? Number.MAX_SAFE_INTEGER;

    if (leftChapterOrder !== rightChapterOrder) {
      return leftChapterOrder - rightChapterOrder;
    }

    return left.order - right.order;
  });
}

function buildScopeSnapshot(
  project: ProjectRecord,
  chapters: ChapterRecord[],
  scopedScenes: SceneRecord[]
): string {
  if (scopedScenes.length === 0) {
    return "";
  }

  const chapterMap = new Map(chapters.map((chapter) => [chapter.id, chapter]));
  const parts: string[] = [`Project: ${project.title}`];
  let previousChapterId: string | null = null;

  for (const scopedScene of scopedScenes) {
    const chapter = chapterMap.get(scopedScene.chapterId) ?? null;
    if (chapter && chapter.id !== previousChapterId) {
      parts.push("", `Chapter: ${chapter.title}`);
      previousChapterId = chapter.id;
    }

    parts.push("", `Scene: ${scopedScene.title}`, "", scopedScene.contentText || "");
  }

  return parts.join("\n").trim();
}

function selectAllCompositeText(root: HTMLElement | null) {
  if (!root) {
    return false;
  }

  const proseMirrors = Array.from(root.querySelectorAll(".composite-writing-column .ProseMirror"));
  const firstEditor = proseMirrors[0] ?? null;
  const lastEditor = proseMirrors[proseMirrors.length - 1] ?? null;
  if (!(firstEditor instanceof HTMLElement) || !(lastEditor instanceof HTMLElement)) {
    return false;
  }

  const selection = window.getSelection();
  if (!selection) {
    return false;
  }

  const firstTextNode = getFirstTextNode(firstEditor);
  const lastTextNode = getLastTextNode(lastEditor);
  const range = document.createRange();

  if (firstTextNode) {
    range.setStart(firstTextNode, 0);
  } else {
    range.setStart(firstEditor, 0);
  }

  if (lastTextNode) {
    range.setEnd(lastTextNode, lastTextNode.textContent?.length ?? 0);
  } else {
    range.setEnd(lastEditor, lastEditor.childNodes.length);
  }

  selection.removeAllRanges();
  selection.addRange(range);
  return true;
}

function getFirstTextNode(root: Node): Text | null {
  if (root.nodeType === Node.TEXT_NODE) {
    return root.textContent && root.textContent.length > 0 ? (root as Text) : null;
  }

  for (const child of Array.from(root.childNodes)) {
    const match = getFirstTextNode(child);
    if (match) {
      return match;
    }
  }

  return null;
}

function getLastTextNode(root: Node): Text | null {
  if (root.nodeType === Node.TEXT_NODE) {
    return root.textContent && root.textContent.length > 0 ? (root as Text) : null;
  }

  const children = Array.from(root.childNodes);
  for (let index = children.length - 1; index >= 0; index -= 1) {
    const match = getLastTextNode(children[index]);
    if (match) {
      return match;
    }
  }

  return null;
}

function resolveVerticalSceneSelection(
  view: Editor["view"],
  edge: "start" | "end",
  preferredX?: number | null
) {
  const fallback = edge === "start"
    ? TextSelection.atStart(view.state.doc)
    : TextSelection.atEnd(view.state.doc);
  if (preferredX == null) {
    return fallback;
  }

  try {
    const edgeCoords = view.coordsAtPos(fallback.from);
    const resolved = view.posAtCoords({
      left: preferredX,
      top: edgeCoords.top
    });

    if (!resolved?.pos) {
      return fallback;
    }

    const safePos = Math.max(1, Math.min(resolved.pos, view.state.doc.content.size));
    return TextSelection.create(view.state.doc, safePos);
  } catch {
    return fallback;
  }
}

function ContinuousWritingIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      className="continuous-writing-icon"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M5 6h8l4 4v8H5z" />
      <path d="M13 6v4h4" />
      <path d="M8 13c1.2-1 2.4-1 3.6 0s2.4 1 3.6 0" />
      <path d="M8 17c1.2-1 2.4-1 3.6 0s2.4 1 3.6 0" />
    </svg>
  );
}
