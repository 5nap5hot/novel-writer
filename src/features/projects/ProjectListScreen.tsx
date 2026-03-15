import { useEffect, useRef, useState, type ChangeEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useShallow } from "zustand/react/shallow";

import { AccountStatus } from "../../components/AccountStatus";
import { AppHeader } from "../../components/AppHeader";
import { SyncStatusBadge } from "../../components/SyncStatusBadge";
import { ThemeToggleButton } from "../../components/ThemeToggleButton";
import { listProjectSummaries } from "../../db/repositories";
import { importScrivenerDocx } from "../../import/service";
import { getSupabaseClient } from "../../lib/supabase";
import { useAppStore } from "../../state/appStore";
import type { TrashItemRecord } from "../../types/models";

export function ProjectListScreen() {
  const importInputRef = useRef<HTMLInputElement | null>(null);
  const [projectSummaries, setProjectSummaries] = useState<Record<string, {
    chapterCount: number;
    wordCount: number;
  }>>({});
  const [importMessage, setImportMessage] = useState<string | null>(null);
  const [isImporting, setIsImporting] = useState(false);
  const [pendingDelete, setPendingDelete] = useState<null | {
    kind: "project" | "trash";
    id: string;
    title: string;
  }>(null);
  const navigate = useNavigate();
  const {
    projects,
    projectTrashItems,
    authMode,
    currentUser,
    syncStatus,
    pendingSyncCount,
    conflictCount,
    pendingDeletionUndo,
    runManualSync,
    refreshProjects,
    createProjectAndOpen,
    deleteProjectById,
    undoPendingDeletion,
    restoreProjectTrashItemById,
    permanentlyDeleteProjectTrashItemById,
    signOutToSupabaseMode
  } = useAppStore(useShallow((state) => ({
    projects: state.projects,
    projectTrashItems: state.projectTrashItems,
    authMode: state.authMode,
    currentUser: state.currentUser,
    syncStatus: state.syncStatus,
    pendingSyncCount: state.pendingSyncCount,
    conflictCount: state.conflictCount,
    pendingDeletionUndo: state.pendingDeletionUndo,
    runManualSync: state.runManualSync,
    refreshProjects: state.refreshProjects,
    createProjectAndOpen: state.createProjectAndOpen,
    deleteProjectById: state.deleteProjectById,
    undoPendingDeletion: state.undoPendingDeletion,
    restoreProjectTrashItemById: state.restoreProjectTrashItemById,
    permanentlyDeleteProjectTrashItemById: state.permanentlyDeleteProjectTrashItemById,
    signOutToSupabaseMode: state.signOutToSupabaseMode
  })));

  useEffect(() => {
    void refreshProjects();
  }, [refreshProjects]);

  useEffect(() => {
    let isCancelled = false;

    async function loadSummaries() {
      const summaries = await listProjectSummaries({
        ownerUserId:
          authMode === "supabase"
            ? currentUser?.id ?? "__signed_out__"
            : null,
        includeAnonymous: false
      });

      if (isCancelled) {
        return;
      }

      setProjectSummaries(
        Object.fromEntries(
          summaries.map((summary) => [
            summary.projectId,
            {
              chapterCount: summary.chapterCount,
              wordCount: summary.wordCount
            }
          ])
        )
      );
    }

    void loadSummaries();

    return () => {
      isCancelled = true;
    };
  }, [authMode, currentUser?.id, projects, projectTrashItems]);

  async function handleCreateProject() {
    const project = await createProjectAndOpen();
    const sceneId = useAppStore.getState().selectedSceneId;
    navigate(
      sceneId
        ? `/projects/${project.id}/scenes/${sceneId}`
        : `/projects/${project.id}`
    );
  }

  async function handleSignOut() {
    const client = getSupabaseClient();
    if (client) {
      await client.auth.signOut();
    }
    await signOutToSupabaseMode();
    navigate("/login");
  }

  async function handleImportDocx(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0] ?? null;
    if (!file) {
      return;
    }

    setImportMessage(null);
    setIsImporting(true);

    try {
      const imported = await importScrivenerDocx(
        file,
        authMode === "supabase" ? currentUser?.id ?? null : null
      );
      await refreshProjects();
      navigate(`/projects/${imported.projectId}`);
    } catch (error) {
      setImportMessage(error instanceof Error ? error.message : "Import failed.");
    } finally {
      setIsImporting(false);
      if (importInputRef.current) {
        importInputRef.current.value = "";
      }
    }
  }

  return (
    <div className="page-shell">
      <AppHeader
        rightSlot={
          <>
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
            {!(authMode === "supabase" && currentUser) ? (
              <Link className="secondary-button" to="/login">
                Login
              </Link>
            ) : null}
          </>
        }
      />
      <main className="page-content">
        <section className="panel">
          <div className="panel-heading">
            <div>
              <p className="section-label">Milestone 1</p>
              <h1>Projects</h1>
            </div>
            <div className="button-row">
              <input
                ref={importInputRef}
                className="visually-hidden"
                type="file"
                accept=".docx,application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                onChange={(event) => void handleImportDocx(event)}
              />
              <button
                className="secondary-button"
                type="button"
                disabled={isImporting}
                onClick={() => importInputRef.current?.click()}
              >
                {isImporting ? "Importing..." : "Import DOCX"}
              </button>
              <button onClick={() => void handleCreateProject()}>New Project</button>
            </div>
          </div>

          {importMessage ? (
            <div className="auth-message is-error">{importMessage}</div>
          ) : null}

          {projects.length === 0 ? (
            <div className="empty-state">
              <h2>No novels yet</h2>
              <p>Create your first project. New projects default to the title “New Novel”.</p>
            </div>
          ) : (
            <div className="project-grid">
              {projects.map((project) => (
                <div key={project.id} className="project-card-shell">
                  <button
                    className="project-card"
                    onClick={() => navigate(`/projects/${project.id}`)}
                  >
                    <span className="project-card-title">{project.title}</span>
                    <div className="project-card-stats">
                      <span>{(projectSummaries[project.id]?.chapterCount ?? 0).toLocaleString()} chapters</span>
                      <span>{(projectSummaries[project.id]?.wordCount ?? 0).toLocaleString()} words</span>
                    </div>
                    <span className="project-card-meta">
                      Updated {new Date(project.updatedAt).toLocaleString()}
                    </span>
                  </button>
                  <button
                    className="row-action-button project-card-delete"
                    type="button"
                    onClick={() => setPendingDelete({
                      kind: "project",
                      id: project.id,
                      title: project.title
                    })}
                    aria-label={`Delete ${project.title}`}
                    title="Delete project"
                  >
                    <TrashIcon />
                  </button>
                </div>
              ))}
            </div>
          )}

          <div className="project-trash-panel">
            <div className="panel-heading">
              <div>
                <p className="section-label">Trash</p>
                <h2>Deleted Projects</h2>
              </div>
            </div>
            {projectTrashItems.length === 0 ? (
              <div className="empty-state compact-empty-state">
                <p>Project Trash is empty.</p>
              </div>
            ) : (
              <div className="project-trash-list">
                {projectTrashItems.map((trashItem) => (
                  <ProjectTrashRow
                    key={trashItem.id}
                    trashItem={trashItem}
                    onRestore={() => void restoreProjectTrashItemById(trashItem.id)}
                    onDeletePermanently={() => setPendingDelete({
                      kind: "trash",
                      id: trashItem.id,
                      title: trashItem.title
                    })}
                  />
                ))}
              </div>
            )}
          </div>
        </section>
      </main>

      {pendingDelete ? (
        <div className="confirm-dialog-backdrop" role="presentation">
          <div className="confirm-dialog" role="alertdialog" aria-modal="true" aria-labelledby="project-delete-title">
            <h2 id="project-delete-title">
              {pendingDelete.kind === "project" ? "Delete Project?" : "Delete Project Permanently?"}
            </h2>
            <p>
              {pendingDelete.kind === "project"
                ? "This will move the project, its chapters, and its scenes to Trash."
                : "This will permanently remove the project from Trash."}
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
                  if (nextDelete.kind === "project") {
                    void deleteProjectById(nextDelete.id);
                    return;
                  }
                  void permanentlyDeleteProjectTrashItemById(nextDelete.id);
                }}
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {pendingDeletionUndo?.kind === "project" ? (
        <div className="undo-toast" role="status" aria-live="polite">
          <span>{pendingDeletionUndo.message}</span>
          <button
            className="secondary-button"
            type="button"
            onClick={() => void undoPendingDeletion()}
          >
            Undo
          </button>
        </div>
      ) : null}
    </div>
  );
}

function ProjectTrashRow({
  trashItem,
  onRestore,
  onDeletePermanently
}: {
  trashItem: TrashItemRecord;
  onRestore: () => void;
  onDeletePermanently: () => void;
}) {
  const payload = trashItem.payload as {
    chapters: { id: string }[];
    scenes: { id: string }[];
  };
  const chapterCount = payload.chapters.length;
  const sceneCount = payload.scenes.length;

  return (
    <div className="project-trash-row">
      <div className="project-trash-copy">
        <strong>{trashItem.title}</strong>
        <span>
          {chapterCount} chapter{chapterCount === 1 ? "" : "s"} · {sceneCount} scene{sceneCount === 1 ? "" : "s"}
        </span>
      </div>
      <div className="project-trash-actions">
        <button className="secondary-button" type="button" onClick={onRestore}>
          Restore
        </button>
        <button
          className="row-action-button is-visible"
          type="button"
          onClick={onDeletePermanently}
          aria-label="Delete project permanently"
          title="Delete permanently"
        >
          <TrashIcon />
        </button>
      </div>
    </div>
  );
}

function TrashIcon() {
  return (
    <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M4.5 6.5h11" />
      <path d="M7.5 3.75h5" />
      <path d="M6.25 6.5l.7 9h6.1l.7-9" />
      <path d="M8.25 8.75v4.5" />
      <path d="M11.75 8.75v4.5" />
    </svg>
  );
}
