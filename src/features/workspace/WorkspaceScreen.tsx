import { useEffect, useState } from "react";
import { Link, useLocation, useNavigate, useParams } from "react-router-dom";
import { useShallow } from "zustand/react/shallow";

import { AccountStatus } from "../../components/AccountStatus";
import { AppHeader } from "../../components/AppHeader";
import { ThemeToggleButton } from "../../components/ThemeToggleButton";
import { BinderSidebar } from "../../binder/BinderSidebar";
import { ExportMenu } from "../../components/ExportMenu";
import { SyncStatusBadge } from "../../components/SyncStatusBadge";
import { EditorShell } from "./EditorShell";
import { useAppStore } from "../../state/appStore";
import { getSupabaseClient } from "../../lib/supabase";

export function WorkspaceScreen() {
  const [selectedTrashItemId, setSelectedTrashItemId] = useState<string | null>(null);
  const [pendingDelete, setPendingDelete] = useState<null | {
    kind: "chapter" | "scene" | "trash";
    id: string;
    title: string;
    sceneCount?: number;
  }>(null);
  const [pendingEditorFocusSceneId, setPendingEditorFocusSceneId] = useState<string | null>(null);
  const { projectId, sceneId } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const {
    isLoading,
    activeProject,
    chapters,
    scenes,
    trashItems,
    selectedChapterId,
    selectedSceneId,
    selectedChapterIds,
    selectedSceneIds,
    expandedChapterIds,
    editorZoomPercent,
    authMode,
    currentUser,
    syncStatus,
    pendingSyncCount,
    conflictCount,
    pendingDeletionUndo,
    loadProject,
    runManualSync,
    setSelectedScene,
    selectBinderItem,
    toggleChapterExpansion,
    reorderChaptersInActiveProject,
    moveSceneInBinder,
    createChapterInActiveProject,
    createSceneInSelectedChapter,
    renameProject,
    renameChapter,
    renameScene,
    deleteChapterById,
    deleteSceneById,
    undoPendingDeletion,
    clearPendingDeletionUndo,
    restoreTrashItemById,
    permanentlyDeleteTrashItemById,
    updateSceneDraftLocal,
    saveSceneDraft,
    saveSceneEditorState,
    getSceneEditorState,
    setEditorZoom,
    signOutToSupabaseMode
  } = useAppStore(useShallow((state) => ({
    isLoading: state.isLoading,
    activeProject: state.activeProject,
    chapters: state.chapters,
    scenes: state.scenes,
    trashItems: state.trashItems,
    selectedChapterId: state.selectedChapterId,
    selectedSceneId: state.selectedSceneId,
    selectedChapterIds: state.selectedChapterIds,
    selectedSceneIds: state.selectedSceneIds,
    expandedChapterIds: state.expandedChapterIds,
    editorZoomPercent: state.editorZoomPercent,
    authMode: state.authMode,
    currentUser: state.currentUser,
    syncStatus: state.syncStatus,
    pendingSyncCount: state.pendingSyncCount,
    conflictCount: state.conflictCount,
    pendingDeletionUndo: state.pendingDeletionUndo,
    loadProject: state.loadProject,
    runManualSync: state.runManualSync,
    setSelectedScene: state.setSelectedScene,
    selectBinderItem: state.selectBinderItem,
    toggleChapterExpansion: state.toggleChapterExpansion,
    reorderChaptersInActiveProject: state.reorderChaptersInActiveProject,
    moveSceneInBinder: state.moveSceneInBinder,
    createChapterInActiveProject: state.createChapterInActiveProject,
    createSceneInSelectedChapter: state.createSceneInSelectedChapter,
    renameProject: state.renameProject,
    renameChapter: state.renameChapter,
    renameScene: state.renameScene,
    deleteChapterById: state.deleteChapterById,
    deleteSceneById: state.deleteSceneById,
    undoPendingDeletion: state.undoPendingDeletion,
    clearPendingDeletionUndo: state.clearPendingDeletionUndo,
    restoreTrashItemById: state.restoreTrashItemById,
    permanentlyDeleteTrashItemById: state.permanentlyDeleteTrashItemById,
    updateSceneDraftLocal: state.updateSceneDraftLocal,
    saveSceneDraft: state.saveSceneDraft,
    saveSceneEditorState: state.saveSceneEditorState,
    getSceneEditorState: state.getSceneEditorState,
    setEditorZoom: state.setEditorZoom,
    signOutToSupabaseMode: state.signOutToSupabaseMode
  })));

  async function handleSignOut() {
    const client = getSupabaseClient();
    if (client) {
      await client.auth.signOut();
    }
    await signOutToSupabaseMode();
    navigate("/login");
  }

  useEffect(() => {
    if (!projectId) {
      return;
    }

    if (activeProject?.id === projectId) {
      return;
    }

    void loadProject(projectId);
  }, [activeProject?.id, loadProject, projectId]);

  useEffect(() => {
    if (!sceneId) {
      return;
    }

    if (useAppStore.getState().selectedSceneId === sceneId) {
      return;
    }

    void setSelectedScene(sceneId);
  }, [sceneId, setSelectedScene]);

  useEffect(() => {
    if (!activeProject?.id || !projectId || activeProject.id !== projectId || isLoading) {
      return;
    }

    const targetPath = selectedSceneIds.length > 1
      ? `/projects/${activeProject.id}`
      : selectedSceneId
      ? `/projects/${activeProject.id}/scenes/${selectedSceneId}`
      : `/projects/${activeProject.id}`;

    if (location.pathname === targetPath) {
      return;
    }

    if (selectedSceneIds.length === 1 && selectedSceneId) {
      navigate(targetPath, {
        replace: true
      });
      return;
    }

    navigate(targetPath, { replace: true });
  }, [activeProject?.id, isLoading, location.pathname, navigate, projectId, selectedSceneId, selectedSceneIds.length]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (
        target &&
        (
          target.tagName === "INPUT" ||
          target.tagName === "TEXTAREA" ||
          target.tagName === "SELECT" ||
          target.isContentEditable
        )
      ) {
        return;
      }

      const isFocusInsideWorkspace =
        target instanceof Element && Boolean(target.closest(".workspace-shell"));
      if (!isFocusInsideWorkspace) {
        return;
      }

      if ((event.metaKey || event.ctrlKey) && event.shiftKey && event.key.toLowerCase() === "n") {
        event.preventDefault();
        void createSceneInSelectedChapter().then((createdScene) => {
          if (createdScene) {
            setPendingEditorFocusSceneId(createdScene.id);
          }
        });
        return;
      }

      if ((event.metaKey || event.ctrlKey) && event.altKey && event.key.toLowerCase() === "n") {
        event.preventDefault();
        void createChapterInActiveProject();
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [createChapterInActiveProject, createSceneInSelectedChapter]);

  const selectedScenes = scenes.filter((scene) => selectedSceneIds.includes(scene.id));
  const selectedScene =
    scenes.find((scene) => scene.id === selectedSceneId) ??
    (selectedSceneId === null && selectedScenes.length === 1 ? selectedScenes[0] : null);
  const explicitSelectedSceneIds = selectedSceneIds.filter((id) => {
    const chapterId = scenes.find((scene) => scene.id === id)?.chapterId ?? null;
    return chapterId == null || !selectedChapterIds.includes(chapterId);
  });
  const isCombinedSelection = selectedChapterIds.length + explicitSelectedSceneIds.length > 1;
  const projectWordCount = scenes.reduce((total, entry) => total + entry.wordCount, 0);
  const selectedTrashItem = trashItems.find((item) => item.id === selectedTrashItemId) ?? null;
  const previewChapter =
    selectedTrashItem?.entityType === "chapter"
      ? (selectedTrashItem.payload as { chapter: typeof chapters[number] }).chapter
      : selectedTrashItem?.entityType === "scene"
        ? ({
            id: selectedTrashItem.originalParentId ?? `trash-preview-${selectedTrashItem.id}`,
            projectId: activeProject?.id ?? "",
            title: selectedTrashItem.originalParentTitle ?? "Unknown Chapter",
            order: selectedTrashItem.originalIndex,
            createdAt: selectedTrashItem.deletedAt,
            updatedAt: selectedTrashItem.deletedAt,
            lastEditedDeviceId: null,
            lastSyncedAt: null,
            remoteUpdatedAt: null,
            syncError: null,
            syncStatus: "saved_locally" as const
          })
        : null;
  const previewScenes =
    selectedTrashItem?.entityType === "chapter"
      ? (selectedTrashItem.payload as { scenes: typeof scenes }).scenes
      : selectedTrashItem?.entityType === "scene"
        ? [(selectedTrashItem.payload as { scene: typeof scenes[number] }).scene]
        : [];
  const editorChapters = previewChapter
    ? chapters.some((chapter) => chapter.id === previewChapter.id)
      ? chapters
      : [...chapters, previewChapter]
    : chapters;

  if (isLoading || (projectId && activeProject?.id !== projectId)) {
    return (
      <div className="page-shell">
        <AppHeader rightSlot={<Link className="secondary-button" to="/projects">Back to Projects</Link>} />
        <main className="page-content">
          <section className="panel empty-state">
            <h1>Loading workspace</h1>
            <p>Restoring your project, chapter, scene, and binder state.</p>
          </section>
        </main>
      </div>
    );
  }

  if (!activeProject) {
    return (
      <div className="page-shell">
        <AppHeader rightSlot={<Link className="secondary-button" to="/projects">Back to Projects</Link>} />
        <main className="page-content">
          <section className="panel empty-state">
            <h1>Project not found</h1>
            <p>Pick a different project from the project list.</p>
          </section>
        </main>
      </div>
    );
  }

  return (
    <div className="workspace-shell">
      <AppHeader
        rightSlot={
          <>
            <ExportMenu projectId={activeProject.id} />
            <ThemeToggleButton />
            <AccountStatus
              authMode={authMode}
              currentUser={currentUser}
              onSignOut={authMode === "supabase" && currentUser ? () => void handleSignOut() : undefined}
            />
            <SyncStatusBadge
              status={syncStatus}
              pendingCount={pendingSyncCount}
              conflictCount={conflictCount}
              onManualSync={authMode === "supabase" ? () => void runManualSync() : undefined}
            />
            <Link className="secondary-button" to="/projects">All Projects</Link>
          </>
        }
      />
      <main className="workspace-layout">
        <BinderSidebar
          project={activeProject}
          projectWordCount={projectWordCount}
          chapters={chapters}
          scenes={scenes}
          trashItems={trashItems}
          selectedChapterId={selectedChapterId}
          selectedSceneId={selectedSceneId}
          selectedChapterIds={selectedChapterIds}
          selectedSceneIds={selectedSceneIds}
          selectedTrashItemId={selectedTrashItemId}
          expandedChapterIds={expandedChapterIds}
          onRenameProject={(title) => void renameProject(activeProject.id, title)}
          onRenameChapter={(chapterId, title) => void renameChapter(chapterId, title)}
          onRenameScene={(sceneId, title) => void renameScene(sceneId, title)}
          onSelectChapter={(chapterId, mode) => {
            setSelectedTrashItemId(null);
            void selectBinderItem("chapter", chapterId, mode);
          }}
          onSelectScene={(nextSceneId, mode) => {
            setSelectedTrashItemId(null);
            void selectBinderItem("scene", nextSceneId, mode);
          }}
          onToggleChapter={(chapterId) => void toggleChapterExpansion(chapterId)}
          onReorderChapters={(orderedChapterIds) => void reorderChaptersInActiveProject(orderedChapterIds)}
          onMoveScene={(draggedSceneId, targetChapterId, targetOrder) =>
            void moveSceneInBinder(draggedSceneId, targetChapterId, targetOrder)
          }
          onCreateChapter={() => void createChapterInActiveProject()}
          onCreateScene={() => {
            setSelectedTrashItemId(null);
            void createSceneInSelectedChapter().then((createdScene) => {
              if (createdScene) {
                setPendingEditorFocusSceneId(createdScene.id);
              }
            });
          }}
          onDeleteChapter={(chapterId) => {
            const chapter = chapters.find((entry) => entry.id === chapterId);
            if (!chapter) {
              return;
            }

            setPendingDelete({
              kind: "chapter",
              id: chapterId,
              title: chapter.title,
              sceneCount: scenes.filter((scene) => scene.chapterId === chapterId).length
            });
          }}
          onDeleteScene={(sceneId) => {
            const scene = scenes.find((entry) => entry.id === sceneId);
            if (!scene) {
              return;
            }

            setPendingDelete({
              kind: "scene",
              id: sceneId,
              title: scene.title
            });
          }}
          onSelectTrashItem={(trashItemId) => setSelectedTrashItemId(trashItemId)}
          onRestoreTrashItem={(trashItemId) => {
            if (selectedTrashItemId === trashItemId) {
              setSelectedTrashItemId(null);
            }
            void restoreTrashItemById(trashItemId);
          }}
          onPermanentDeleteTrashItem={(trashItemId) => {
            const trashItem = trashItems.find((entry) => entry.id === trashItemId);
            if (!trashItem) {
              return;
            }

            if (selectedTrashItemId === trashItemId) {
              setSelectedTrashItemId(null);
            }

            const payload = trashItem.payload as { scenes?: { id: string }[] };
            setPendingDelete({
              kind: "trash",
              id: trashItemId,
              title: trashItem.title,
              sceneCount: Array.isArray(payload.scenes) ? payload.scenes.length : undefined
            });
          }}
        />

        <EditorShell
          project={activeProject}
          chapters={editorChapters}
          scenes={scenes}
          scene={selectedTrashItem ? (previewScenes[0] ?? null) : selectedScene}
          selectedScenes={selectedTrashItem ? previewScenes : selectedScenes}
          isCombinedSelection={selectedTrashItem ? false : isCombinedSelection}
          editorZoomPercent={editorZoomPercent}
          onRenameScene={(title) => selectedScene && void renameScene(selectedScene.id, title)}
          onUpdateSceneDraftLocal={updateSceneDraftLocal}
          onSaveSceneDraft={saveSceneDraft}
          onSaveSceneEditorState={saveSceneEditorState}
          onLoadSceneEditorState={getSceneEditorState}
          onSetEditorZoom={setEditorZoom}
          focusSceneId={pendingEditorFocusSceneId}
          onSceneFocusHandled={(sceneId) => {
            if (sceneId === pendingEditorFocusSceneId) {
              setPendingEditorFocusSceneId(null);
            }
          }}
          readOnly={Boolean(selectedTrashItem)}
          previewLabel={
            selectedTrashItem
              ? selectedTrashItem.entityType === "chapter"
                ? `Trash Preview · Chapter: ${selectedTrashItem.title}`
                : `Trash Preview · ${selectedTrashItem.originalParentTitle ?? "Unknown Chapter"} / ${selectedTrashItem.title}`
              : null
          }
        />
      </main>
      {pendingDelete ? (
        <div className="confirm-dialog-backdrop" role="presentation">
          <div className="confirm-dialog" role="dialog" aria-modal="true" aria-labelledby="delete-dialog-title">
            <h2 id="delete-dialog-title">
              {pendingDelete.kind === "chapter"
                ? "Delete Chapter?"
                : pendingDelete.kind === "scene"
                  ? "Delete Scene?"
                  : "Delete Permanently?"}
            </h2>
            <p>
              {pendingDelete.kind === "chapter"
                ? "This will remove the chapter and all scenes inside it."
                : pendingDelete.kind === "scene"
                  ? "This will remove the scene from your project."
                  : "This will permanently remove the item from Trash."}
            </p>
            <div className="button-row">
              <button
                className="secondary-button"
                type="button"
                autoFocus
                onClick={() => setPendingDelete(null)}
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => {
                  const nextDelete = pendingDelete;
                  setPendingDelete(null);
                  if (nextDelete.kind === "chapter") {
                    void deleteChapterById(nextDelete.id);
                    return;
                  }

                  if (nextDelete.kind === "trash") {
                    void permanentlyDeleteTrashItemById(nextDelete.id);
                    return;
                  }

                  void deleteSceneById(nextDelete.id);
                }}
              >
                {pendingDelete.kind === "trash" ? "Delete Permanently" : "Delete"}
              </button>
            </div>
          </div>
        </div>
      ) : null}
      {pendingDeletionUndo ? (
        <div className="undo-toast" role="status" aria-live="polite">
          <span>{pendingDeletionUndo.message}</span>
          <div className="button-row">
            <button className="secondary-button" type="button" onClick={() => void undoPendingDeletion()}>
              Undo
            </button>
            <button className="ghost-button" type="button" onClick={clearPendingDeletionUndo}>
              Dismiss
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
