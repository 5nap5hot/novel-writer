import { create } from "zustand";

import type {
  AuthenticatedUser,
  AuthMode,
  ChapterRecord,
  ProjectRecord,
  RichTextContent,
  SceneRecord,
  SyncStatus,
  TrashItemRecord,
  WorkspaceSession
} from "../types/models";
import {
  claimAnonymousProjectsForUser,
  createChapter,
  createProjectWithInitialStructure,
  createScene,
  ensureDeviceIdentity,
  getSceneEditorSession,
  getProjectBundle,
  getSyncQueueSize,
  listProjectTrashItems,
  listTrashItems,
  listSceneConflicts,
  moveChapterToTrash,
  moveProjectToTrash,
  moveSceneToTrash,
  listProjects,
  moveSceneToChapterPosition,
  permanentlyDeleteTrashItem,
  persistWorkspaceSession,
  reorderChapters,
  restoreTrashItem,
  saveSceneEditorSession,
  updateChapterTitle,
  updateProjectTitle,
  updateSceneContent,
  updateSceneTitle
} from "../db/repositories";
import { defaultWorkspaceSession, getWorkspaceSession } from "../db/session";
import { nowIso } from "../lib/time";
import { getTextMetrics, sanitizeRichTextContent } from "../lib/editorContent";
import { getSupabaseAuthUser } from "../lib/supabase";
import { runSyncCycle } from "../sync/service";

interface ProjectSelection {
  selectedChapterId: string | null;
  selectedSceneId: string | null;
}

type BinderSelectionMode = "single" | "toggle" | "range";
type BinderItemType = "chapter" | "scene";
type BinderItemKey = `${BinderItemType}:${string}`;

const sceneSaveQueues = new Map<string, Promise<void>>();

interface LoadProjectOptions {
  preferredChapterId?: string | null;
  preferredSceneId?: string | null;
  skipLoadingState?: boolean;
}

interface InitializeOptions {
  restoreWorkspace?: boolean;
}

interface AppStoreState {
  isBootstrapped: boolean;
  isLoading: boolean;
  authMode: AuthMode;
  currentUser: AuthenticatedUser | null;
  projects: ProjectRecord[];
  activeProject: ProjectRecord | null;
  chapters: ChapterRecord[];
  scenes: SceneRecord[];
  projectTrashItems: TrashItemRecord[];
  trashItems: TrashItemRecord[];
  selectedChapterId: string | null;
  selectedSceneId: string | null;
  selectedChapterIds: string[];
  selectedSceneIds: string[];
  selectionAnchorKey: BinderItemKey | null;
  expandedChapterIds: string[];
  editorZoomPercent: number;
  isOnline: boolean;
  isSyncing: boolean;
  syncStatus: SyncStatus;
  lastSyncAt: string | null;
  syncMessage: string | null;
  pendingSyncCount: number;
  conflictCount: number;
  deviceId: string | null;
  pendingDeletionUndo: PendingDeletionUndo | null;
  initialize: (options?: InitializeOptions) => Promise<void>;
  refreshSyncState: () => Promise<void>;
  setOnlineStatus: (isOnline: boolean) => Promise<void>;
  runManualSync: () => Promise<void>;
  runBackgroundSync: () => Promise<void>;
  refreshProjects: () => Promise<void>;
  loadProject: (projectId: string, options?: LoadProjectOptions) => Promise<void>;
  createProjectAndOpen: () => Promise<ProjectRecord>;
  deleteProjectById: (projectId: string) => Promise<void>;
  createChapterInActiveProject: () => Promise<ChapterRecord | null>;
  createSceneInSelectedChapter: () => Promise<SceneRecord | null>;
  setSelectedChapter: (chapterId: string | null) => Promise<void>;
  setSelectedScene: (sceneId: string | null) => Promise<void>;
  selectBinderItem: (
    itemType: BinderItemType,
    itemId: string,
    mode?: BinderSelectionMode
  ) => Promise<void>;
  toggleChapterExpansion: (chapterId: string) => Promise<void>;
  reorderChaptersInActiveProject: (orderedChapterIds: string[]) => Promise<void>;
  moveSceneInBinder: (sceneId: string, targetChapterId: string, targetOrder: number) => Promise<void>;
  renameProject: (projectId: string, title: string) => Promise<void>;
  renameChapter: (chapterId: string, title: string) => Promise<void>;
  renameScene: (sceneId: string, title: string) => Promise<void>;
  deleteChapterById: (chapterId: string) => Promise<void>;
  deleteSceneById: (sceneId: string) => Promise<void>;
  undoPendingDeletion: () => Promise<void>;
  clearPendingDeletionUndo: () => void;
  restoreTrashItemById: (trashItemId: string) => Promise<void>;
  restoreProjectTrashItemById: (trashItemId: string) => Promise<void>;
  permanentlyDeleteTrashItemById: (trashItemId: string) => Promise<void>;
  permanentlyDeleteProjectTrashItemById: (trashItemId: string) => Promise<void>;
  updateSceneDraftLocal: (sceneId: string, contentJson: RichTextContent) => void;
  saveSceneDraft: (sceneId: string, contentJson: RichTextContent) => Promise<void>;
  saveSceneEditorState: (
    sceneId: string,
    cursorFrom: number | null,
    cursorTo: number | null,
    scrollTop: number
  ) => Promise<void>;
  getSceneEditorState: (sceneId: string) => Promise<{
    cursorFrom: number | null;
    cursorTo: number | null;
    scrollTop: number;
  } | null>;
  setEditorZoom: (zoomPercent: number) => Promise<void>;
  setAuthMode: (mode: AuthMode) => Promise<void>;
  setCurrentUser: (user: AuthenticatedUser | null) => Promise<void>;
  completeSupabaseAuth: () => Promise<void>;
  signOutToSupabaseMode: () => Promise<void>;
}

type PendingDeletionUndo =
  | {
      kind: "project";
      message: string;
      trashItemId: string;
      project: ProjectRecord;
      chapters: ChapterRecord[];
      scenes: SceneRecord[];
      timeoutId: number | null;
    }
  | {
      kind: "scene";
      message: string;
      trashItemId: string;
      scene: SceneRecord;
      timeoutId: number | null;
    }
  | {
      kind: "chapter";
      message: string;
      trashItemId: string;
      chapter: ChapterRecord;
      scenes: SceneRecord[];
      timeoutId: number | null;
    };

function getExpandedChapters(
  session: WorkspaceSession,
  projectId: string | null
): string[] {
  if (!projectId) {
    return [];
  }

  return session.expandedChapterIdsByProject[projectId] ?? [];
}

function resolveSelection(
  chapters: ChapterRecord[],
  scenes: SceneRecord[],
  preferredChapterId: string | null,
  preferredSceneId: string | null
): ProjectSelection {
  const selectedScene = preferredSceneId
    ? scenes.find((scene) => scene.id === preferredSceneId) ?? null
    : null;

  if (selectedScene) {
    return {
      selectedChapterId: selectedScene.chapterId,
      selectedSceneId: selectedScene.id
    };
  }

  const selectedChapter = preferredChapterId
    ? chapters.find((chapter) => chapter.id === preferredChapterId) ?? null
    : null;

  if (selectedChapter) {
    return {
      selectedChapterId: selectedChapter.id,
      selectedSceneId: null
    };
  }

  const firstChapter = chapters[0] ?? null;
  if (!firstChapter) {
    return {
      selectedChapterId: null,
      selectedSceneId: null
    };
  }

  const firstSceneInChapter =
    scenes.find((scene) => scene.chapterId === firstChapter.id) ?? null;

  return {
    selectedChapterId: firstChapter.id,
    selectedSceneId: firstSceneInChapter?.id ?? null
  };
}

function patchProjectListItem(
  projects: ProjectRecord[],
  projectId: string,
  patch: Partial<ProjectRecord>
): ProjectRecord[] {
  return projects.map((project) =>
    project.id === projectId ? { ...project, ...patch } : project
  );
}

function toBinderItemKey(itemType: BinderItemType, itemId: string): BinderItemKey {
  return `${itemType}:${itemId}`;
}

function flattenBinderItemKeys(
  chapters: ChapterRecord[],
  scenes: SceneRecord[]
): BinderItemKey[] {
  return chapters.flatMap((chapter) => {
    const chapterScenes = scenes
      .filter((scene) => scene.chapterId === chapter.id)
      .sort((left, right) => left.order - right.order);

    return [
      toBinderItemKey("chapter", chapter.id),
      ...chapterScenes.map((scene) => toBinderItemKey("scene", scene.id))
    ];
  });
}

function deriveSelectionFromKeys(
  keys: BinderItemKey[],
  scenes: SceneRecord[]
): {
  selectedChapterIds: string[];
  selectedSceneIds: string[];
} {
  const selectedChapterIds: string[] = [];
  const selectedSceneIds: string[] = [];

  for (const key of keys) {
    const [itemType, itemId] = key.split(":") as [BinderItemType, string];

    if (itemType === "chapter") {
      if (!selectedChapterIds.includes(itemId)) {
        selectedChapterIds.push(itemId);
      }

      for (const scene of scenes) {
        if (scene.chapterId === itemId && !selectedSceneIds.includes(scene.id)) {
          selectedSceneIds.push(scene.id);
        }
      }

      continue;
    }

    if (!selectedSceneIds.includes(itemId)) {
      selectedSceneIds.push(itemId);
    }
  }

  return {
    selectedChapterIds,
    selectedSceneIds
  };
}

function createSingleSelectionPatch(
  itemType: BinderItemType,
  itemId: string,
  scenes: SceneRecord[]
) {
  const itemKey = toBinderItemKey(itemType, itemId);
  const nextChapterId =
    itemType === "chapter"
      ? itemId
      : scenes.find((scene) => scene.id === itemId)?.chapterId ?? null;
  const nextSceneId = itemType === "scene" ? itemId : null;
  const derived = deriveSelectionFromKeys([itemKey], scenes);

  return {
    selectedChapterId: nextChapterId,
    selectedSceneId: nextSceneId,
    selectedChapterIds: derived.selectedChapterIds,
    selectedSceneIds: derived.selectedSceneIds,
    selectionAnchorKey: itemKey
  };
}

function resolvePrimarySelectionFromKeys(
  keys: BinderItemKey[],
  scenes: SceneRecord[]
): {
  selectedChapterId: string | null;
  selectedSceneId: string | null;
  selectionAnchorKey: BinderItemKey | null;
} {
  const lastKey = keys[keys.length - 1] ?? null;
  if (!lastKey) {
    return {
      selectedChapterId: null,
      selectedSceneId: null,
      selectionAnchorKey: null
    };
  }

  const [itemType, itemId] = lastKey.split(":") as [BinderItemType, string];
  if (itemType === "chapter") {
    return {
      selectedChapterId: itemId,
      selectedSceneId: null,
      selectionAnchorKey: lastKey
    };
  }

  return {
    selectedChapterId: scenes.find((scene) => scene.id === itemId)?.chapterId ?? null,
    selectedSceneId: itemId,
    selectionAnchorKey: lastKey
  };
}

async function persistSelectionState(
  activeProjectId: string | null,
  selectedChapterId: string | null,
  selectedSceneId: string | null
): Promise<void> {
  await persistWorkspaceSession((current) => ({
    ...current,
    lastProjectId: activeProjectId,
    lastChapterId: selectedChapterId,
    lastSceneId: selectedSceneId
  }));
}

function clearPendingDeletionTimer(pendingDeletionUndo: PendingDeletionUndo | null) {
  if (pendingDeletionUndo?.timeoutId) {
    window.clearTimeout(pendingDeletionUndo.timeoutId);
  }
}

function sortScenesByChapterOrder(
  chapters: ChapterRecord[],
  scenes: SceneRecord[]
): SceneRecord[] {
  const chapterOrder = new Map(chapters.map((chapter) => [chapter.id, chapter.order]));
  return [...scenes].sort((left, right) => {
    const leftChapterOrder = chapterOrder.get(left.chapterId) ?? Number.MAX_SAFE_INTEGER;
    const rightChapterOrder = chapterOrder.get(right.chapterId) ?? Number.MAX_SAFE_INTEGER;

    if (leftChapterOrder !== rightChapterOrder) {
      return leftChapterOrder - rightChapterOrder;
    }

    return left.order - right.order;
  });
}

function getLogicalSelectionKeys(state: Pick<
  AppStoreState,
  "selectedChapterIds" | "selectedSceneIds" | "scenes" | "selectionAnchorKey"
>): BinderItemKey[] {
  const explicitSceneKeys = state.selectedSceneIds
    .filter((sceneId) => {
      const chapterId = state.scenes.find((scene) => scene.id === sceneId)?.chapterId ?? null;
      return chapterId == null || !state.selectedChapterIds.includes(chapterId);
    })
    .map((sceneId) => toBinderItemKey("scene", sceneId));

  const chapterKeys = state.selectedChapterIds.map((chapterId) => toBinderItemKey("chapter", chapterId));
  const orderedKeys = Array.from(new Set([...chapterKeys, ...explicitSceneKeys]));

  if (state.selectionAnchorKey && orderedKeys.includes(state.selectionAnchorKey)) {
    const withoutAnchor = orderedKeys.filter((key) => key !== state.selectionAnchorKey);
    return [...withoutAnchor, state.selectionAnchorKey];
  }

  return orderedKeys;
}

function sortTrashByDeletedAt(items: TrashItemRecord[]): TrashItemRecord[] {
  return [...items].sort((left, right) => right.deletedAt.localeCompare(left.deletedAt));
}

function filterProjectsAgainstTrash(
  projects: ProjectRecord[],
  projectTrashItems: TrashItemRecord[]
): ProjectRecord[] {
  const trashedProjectIds = new Set(
    projectTrashItems
      .filter((item) => item.entityType === "project")
      .map((item) => item.projectId)
  );

  return projects.filter((project) => !trashedProjectIds.has(project.id));
}

function getProjectAccessOptions(state: Pick<AppStoreState, "authMode" | "currentUser">) {
  if (state.authMode === "supabase" && state.currentUser) {
    return {
      ownerUserId: state.currentUser.id,
      includeAnonymous: false
    };
  }

  if (state.authMode === "supabase" && !state.currentUser) {
    return {
      ownerUserId: "__signed_out__",
      includeAnonymous: false
    };
  }

  return {
    ownerUserId: null,
    includeAnonymous: false
  };
}

export const useAppStore = create<AppStoreState>((set, get) => ({
  isBootstrapped: false,
  isLoading: false,
  authMode: "local",
  currentUser: null,
  projects: [],
  activeProject: null,
  chapters: [],
  scenes: [],
  projectTrashItems: [],
  trashItems: [],
  selectedChapterId: null,
  selectedSceneId: null,
  selectedChapterIds: [],
  selectedSceneIds: [],
  selectionAnchorKey: null,
  expandedChapterIds: [],
  editorZoomPercent: 100,
  isOnline: typeof navigator === "undefined" ? true : navigator.onLine,
  isSyncing: false,
  syncStatus: "saved_locally",
  lastSyncAt: null,
  syncMessage: null,
  pendingSyncCount: 0,
  conflictCount: 0,
  deviceId: null,
  pendingDeletionUndo: null,

  initialize: async (options) => {
    const shouldRestoreWorkspace = options?.restoreWorkspace ?? true;
    set({ isLoading: true });

    const [session, device, pendingSyncCount, conflicts] = await Promise.all([
      getWorkspaceSession(),
      ensureDeviceIdentity(),
      getSyncQueueSize(),
      listSceneConflicts()
    ]);
    const currentUser = session.authMode === "supabase"
      ? await getSupabaseAuthUser()
      : null;

    if (session.authMode === "supabase" && currentUser) {
      await claimAnonymousProjectsForUser(currentUser.id);
    }

    const accessOptions = getProjectAccessOptions({
      authMode: session.authMode,
      currentUser
    });
    const [projects, projectTrashItems] = await Promise.all([
      listProjects(accessOptions),
      listProjectTrashItems(accessOptions)
    ]);
    const visibleProjects = filterProjectsAgainstTrash(projects, projectTrashItems);

    if (shouldRestoreWorkspace && session.lastProjectId) {
      const bundle = await getProjectBundle(session.lastProjectId, accessOptions);
      if (bundle) {
        const trashItems = await listTrashItems(session.lastProjectId);
        const selection = resolveSelection(
          bundle.chapters,
          bundle.scenes,
          session.lastChapterId,
          session.lastSceneId
        );

        set({
          projects: visibleProjects,
          projectTrashItems,
          authMode: session.authMode,
          currentUser,
          activeProject: bundle.project,
          chapters: bundle.chapters,
          scenes: bundle.scenes,
          trashItems,
          selectedChapterId: selection.selectedChapterId,
          selectedSceneId: selection.selectedSceneId,
          selectedChapterIds: selection.selectedChapterId ? [selection.selectedChapterId] : [],
          selectedSceneIds: selection.selectedSceneId
            ? [selection.selectedSceneId]
            : selection.selectedChapterId
              ? bundle.scenes
                  .filter((scene) => scene.chapterId === selection.selectedChapterId)
                  .map((scene) => scene.id)
              : [],
          selectionAnchorKey:
            selection.selectedSceneId
              ? toBinderItemKey("scene", selection.selectedSceneId)
              : selection.selectedChapterId
                ? toBinderItemKey("chapter", selection.selectedChapterId)
                : null,
          expandedChapterIds: getExpandedChapters(session, session.lastProjectId),
          editorZoomPercent: session.editorZoomPercent,
          deviceId: device.id,
          pendingSyncCount,
          conflictCount: conflicts.length,
          syncStatus: resolveGlobalSyncStatus({
            isOnline: get().isOnline,
            pendingSyncCount,
            conflictCount: conflicts.length,
            isSyncing: false,
            syncMessage: null
          }),
          isBootstrapped: true,
          isLoading: false
        });

        await persistSelectionState(
          bundle.project.id,
          selection.selectedChapterId,
          selection.selectedSceneId
        );
        return;
      }
    }

    set({
      projects: visibleProjects,
      projectTrashItems,
      authMode: session.authMode,
      currentUser,
      activeProject: null,
      chapters: [],
      scenes: [],
      trashItems: [],
      selectedChapterId: null,
      selectedSceneId: null,
      selectedChapterIds: [],
      selectedSceneIds: [],
      selectionAnchorKey: null,
      expandedChapterIds: [],
      editorZoomPercent: session.editorZoomPercent,
      deviceId: device.id,
      pendingSyncCount,
      conflictCount: conflicts.length,
      syncStatus: resolveGlobalSyncStatus({
        isOnline: get().isOnline,
        pendingSyncCount,
        conflictCount: conflicts.length,
        isSyncing: false,
        syncMessage: null
      }),
      isBootstrapped: true,
      isLoading: false
    });
  },

  refreshSyncState: async () => {
    const [pendingSyncCount, conflicts] = await Promise.all([
      getSyncQueueSize(),
      listSceneConflicts()
    ]);
    const state = get();
    set({
      pendingSyncCount,
      conflictCount: conflicts.length,
      syncStatus: resolveGlobalSyncStatus({
        isOnline: state.isOnline,
        pendingSyncCount,
        conflictCount: conflicts.length,
        isSyncing: state.isSyncing,
        syncMessage: state.syncMessage
      })
    });
  },

  setOnlineStatus: async (isOnline) => {
    const state = get();
    set({
      isOnline,
      syncStatus: resolveGlobalSyncStatus({
        isOnline,
        pendingSyncCount: state.pendingSyncCount,
        conflictCount: state.conflictCount,
        isSyncing: state.isSyncing,
        syncMessage: state.syncMessage
      })
    });
  },

  runManualSync: async () => {
    await runSync(get, set, true);
  },

  runBackgroundSync: async () => {
    await runSync(get, set, false);
  },

  refreshProjects: async () => {
    const accessOptions = getProjectAccessOptions(get());
    const [projects, projectTrashItems] = await Promise.all([
      listProjects(accessOptions),
      listProjectTrashItems(accessOptions)
    ]);
    set({
      projects: filterProjectsAgainstTrash(projects, projectTrashItems),
      projectTrashItems
    });
  },

  loadProject: async (projectId, options) => {
    const state = get();
    const shouldShowLoading = !options?.skipLoadingState;

    if (shouldShowLoading) {
      set({ isLoading: true });
    }

    const session = await getWorkspaceSession();
    const accessOptions = getProjectAccessOptions(state);
    const [bundle, trashItems] = await Promise.all([
      getProjectBundle(projectId, accessOptions),
      listTrashItems(projectId)
    ]);

    if (!bundle) {
      set({ isLoading: false });
      return;
    }

    const preferredChapterId =
      options?.preferredChapterId ?? session.lastChapterId;
    const preferredSceneId =
      options?.preferredSceneId ?? session.lastSceneId;
    const selection = resolveSelection(
      bundle.chapters,
      bundle.scenes,
      preferredChapterId,
      preferredSceneId
    );
    const expandedChapterIds = getExpandedChapters(session, projectId).filter((chapterId) =>
      bundle.chapters.some((chapter) => chapter.id === chapterId)
    );

    set({
      activeProject: bundle.project,
      chapters: bundle.chapters,
      scenes: bundle.scenes,
      trashItems,
      selectedChapterId: selection.selectedChapterId,
      selectedSceneId: selection.selectedSceneId,
      selectedChapterIds: selection.selectedChapterId ? [selection.selectedChapterId] : [],
      selectedSceneIds: selection.selectedSceneId
        ? [selection.selectedSceneId]
        : selection.selectedChapterId
          ? bundle.scenes
              .filter((scene) => scene.chapterId === selection.selectedChapterId)
              .map((scene) => scene.id)
          : [],
      selectionAnchorKey:
        selection.selectedSceneId
          ? toBinderItemKey("scene", selection.selectedSceneId)
          : selection.selectedChapterId
            ? toBinderItemKey("chapter", selection.selectedChapterId)
            : null,
      expandedChapterIds,
      editorZoomPercent: session.editorZoomPercent,
      isLoading: false,
      projects:
        state.projects.length === 0 ? await listProjects(accessOptions) : state.projects
    });

    await persistWorkspaceSession((current) => ({
      ...current,
      lastProjectId: projectId,
      lastChapterId: selection.selectedChapterId,
      lastSceneId: selection.selectedSceneId,
      expandedChapterIdsByProject: {
        ...current.expandedChapterIdsByProject,
        [projectId]: expandedChapterIds
      }
    }));
    await get().refreshSyncState();
  },

  createProjectAndOpen: async () => {
    const state = get();
    const bundle = await createProjectWithInitialStructure(
      "New Novel",
      state.authMode === "supabase" ? state.currentUser?.id ?? null : null
    );
    const expandedChapterIds = [bundle.initialChapter.id];
    const nextProjects = await listProjects(getProjectAccessOptions(get()));

    set({
      projects: nextProjects,
      activeProject: bundle.project,
      chapters: bundle.chapters,
      scenes: bundle.scenes,
      trashItems: [],
      selectedChapterId: bundle.initialChapter.id,
      selectedSceneId: bundle.initialScene.id,
      selectedChapterIds: [bundle.initialChapter.id],
      selectedSceneIds: [bundle.initialScene.id],
      selectionAnchorKey: toBinderItemKey("scene", bundle.initialScene.id),
      expandedChapterIds
    });

    await persistWorkspaceSession((current) => ({
      ...current,
      lastProjectId: bundle.project.id,
      lastChapterId: bundle.initialChapter.id,
      lastSceneId: bundle.initialScene.id,
      expandedChapterIdsByProject: {
        ...current.expandedChapterIdsByProject,
        [bundle.project.id]: expandedChapterIds
      }
    }));

    await get().refreshSyncState();

    return bundle.project;
  },

  deleteProjectById: async (projectId) => {
    const state = get();
    const deletedProject = state.projects.find((project) => project.id === projectId) ?? null;
    if (!deletedProject) {
      return;
    }

    const bundle = await getProjectBundle(projectId, getProjectAccessOptions(state));
    if (!bundle) {
      return;
    }

    const trashItem = await moveProjectToTrash(projectId);
    if (!trashItem) {
      return;
    }

    clearPendingDeletionTimer(state.pendingDeletionUndo);
    const timeoutId = window.setTimeout(() => {
      get().clearPendingDeletionUndo();
    }, 5000);

    set({
      projects: state.projects.filter((project) => project.id !== projectId),
      projectTrashItems: sortTrashByDeletedAt([...state.projectTrashItems, trashItem]),
      pendingDeletionUndo: {
        kind: "project",
        message: "Project deleted.",
        trashItemId: trashItem.id,
        project: bundle.project,
        chapters: bundle.chapters,
        scenes: bundle.scenes,
        timeoutId
      }
    });

    await persistWorkspaceSession((current) => {
      if (current.lastProjectId !== projectId) {
        return current;
      }

      return {
        ...current,
        lastProjectId: null,
        lastChapterId: null,
        lastSceneId: null,
        expandedChapterIdsByProject: Object.fromEntries(
          Object.entries(current.expandedChapterIdsByProject).filter(([key]) => key !== projectId)
        )
      };
    });
    await get().refreshSyncState();
  },

  createChapterInActiveProject: async () => {
    const state = get();
    const projectId = state.activeProject?.id;
    if (!projectId) {
      return null;
    }

    const insertAfterOrder =
      state.selectedChapterId != null
        ? state.chapters.find((chapter) => chapter.id === state.selectedChapterId)?.order ?? null
        : state.selectedSceneId != null
          ? state.chapters.find((chapter) =>
              chapter.id === (state.scenes.find((scene) => scene.id === state.selectedSceneId)?.chapterId ?? "")
            )?.order ?? null
          : state.chapters[state.chapters.length - 1]?.order ?? null;

    const chapter = await createChapter(projectId, insertAfterOrder);
    const initialScene = await createScene(projectId, chapter.id, null);
    const currentExpanded = get().expandedChapterIds;
    const nextExpanded = currentExpanded.includes(chapter.id)
      ? currentExpanded
      : [...currentExpanded, chapter.id];

    await get().loadProject(projectId, {
      preferredChapterId: chapter.id,
      preferredSceneId: initialScene.id,
      skipLoadingState: true
    });

    set({ expandedChapterIds: nextExpanded });

    await persistWorkspaceSession((current) => ({
      ...current,
      lastProjectId: projectId,
      lastChapterId: chapter.id,
      lastSceneId: initialScene.id,
      expandedChapterIdsByProject: {
        ...current.expandedChapterIdsByProject,
        [projectId]: nextExpanded
      }
    }));
    await get().refreshSyncState();

    return chapter;
  },

  createSceneInSelectedChapter: async () => {
    const { activeProject, selectedChapterId, selectedSceneId, scenes } = get();
    if (!activeProject) {
      return null;
    }

    const chapterId =
      (selectedSceneId
        ? scenes.find((scene) => scene.id === selectedSceneId)?.chapterId
        : null) ?? selectedChapterId;

    if (!chapterId) {
      return null;
    }

    const insertAfterOrder =
      selectedSceneId != null
        ? scenes.find((scene) => scene.id === selectedSceneId)?.order ?? null
        : scenes
            .filter((scene) => scene.chapterId === chapterId)
            .sort((left, right) => left.order - right.order)
            .slice(-1)[0]?.order ?? null;

    const scene = await createScene(activeProject.id, chapterId, insertAfterOrder);
    const currentExpanded = get().expandedChapterIds;
    const nextExpanded = currentExpanded.includes(chapterId)
      ? currentExpanded
      : [...currentExpanded, chapterId];

    await get().loadProject(activeProject.id, {
      preferredChapterId: chapterId,
      preferredSceneId: scene.id,
      skipLoadingState: true
    });

    set({ expandedChapterIds: nextExpanded });

    await persistWorkspaceSession((current) => ({
      ...current,
      lastProjectId: activeProject.id,
      lastChapterId: chapterId,
      lastSceneId: scene.id,
      expandedChapterIdsByProject: {
        ...current.expandedChapterIdsByProject,
        [activeProject.id]: nextExpanded
      }
    }));
    await get().refreshSyncState();

    return scene;
  },

  setSelectedChapter: async (chapterId) => {
    const state = get();
    if (!chapterId) {
      set({
        selectedChapterId: null,
        selectedSceneId: null,
        selectedChapterIds: [],
        selectedSceneIds: [],
        selectionAnchorKey: null
      });
      await persistSelectionState(
        state.activeProject?.id ?? null,
        null,
        null
      );
      return;
    }

    set(createSingleSelectionPatch("chapter", chapterId, state.scenes));

    await persistSelectionState(
      state.activeProject?.id ?? null,
      chapterId,
      null
    );
  },

  setSelectedScene: async (sceneId) => {
    const state = get();
    if (!sceneId) {
      set({
        selectedChapterId: null,
        selectedSceneId: null,
        selectedChapterIds: [],
        selectedSceneIds: [],
        selectionAnchorKey: null
      });
      await persistSelectionState(
        state.activeProject?.id ?? null,
        null,
        null
      );
      return;
    }

    const scene = state.scenes.find((entry) => entry.id === sceneId) ?? null;
    const nextChapterId = scene?.chapterId ?? state.selectedChapterId;
    const nextSceneId = scene?.id ?? null;

    set(createSingleSelectionPatch("scene", sceneId, state.scenes));

    await persistSelectionState(
      state.activeProject?.id ?? null,
      nextChapterId,
      nextSceneId
    );
  },

  selectBinderItem: async (itemType, itemId, mode = "single") => {
    const state = get();
    const itemKey = toBinderItemKey(itemType, itemId);

    if (mode === "single") {
      const nextChapterId =
        itemType === "chapter"
          ? itemId
          : state.scenes.find((scene) => scene.id === itemId)?.chapterId ?? null;
      const nextSceneId = itemType === "scene" ? itemId : null;

      set(createSingleSelectionPatch(itemType, itemId, state.scenes));
      await persistSelectionState(
        state.activeProject?.id ?? null,
        nextChapterId,
        nextSceneId
      );
      return;
    }

    const currentKeys = [
      ...state.selectedChapterIds.map((chapterId) => toBinderItemKey("chapter", chapterId)),
      ...state.selectedSceneIds
        .filter((sceneId) => !state.selectedChapterIds.some((chapterId) =>
          state.scenes.find((scene) => scene.id === sceneId)?.chapterId === chapterId
        ))
        .map((sceneId) => toBinderItemKey("scene", sceneId))
    ];
    const dedupedCurrentKeys = Array.from(new Set(currentKeys));

    let nextKeys = dedupedCurrentKeys;
    if (mode === "toggle") {
      nextKeys = dedupedCurrentKeys.includes(itemKey)
        ? dedupedCurrentKeys.filter((key) => key !== itemKey)
        : [...dedupedCurrentKeys, itemKey];
    }

    if (mode === "range") {
      const orderedKeys = flattenBinderItemKeys(state.chapters, state.scenes);
      const anchorKey = state.selectionAnchorKey ?? itemKey;
      const anchorIndex = orderedKeys.indexOf(anchorKey);
      const targetIndex = orderedKeys.indexOf(itemKey);
      if (anchorIndex >= 0 && targetIndex >= 0) {
        const start = Math.min(anchorIndex, targetIndex);
        const end = Math.max(anchorIndex, targetIndex);
        nextKeys = orderedKeys.slice(start, end + 1);
      } else {
        nextKeys = [itemKey];
      }
    }

    const derived = deriveSelectionFromKeys(nextKeys, state.scenes);
    const primarySelection = resolvePrimarySelectionFromKeys(nextKeys, state.scenes);

    set({
      selectedChapterId: primarySelection.selectedChapterId,
      selectedSceneId: primarySelection.selectedSceneId,
      selectedChapterIds: derived.selectedChapterIds,
      selectedSceneIds: derived.selectedSceneIds,
      selectionAnchorKey: primarySelection.selectionAnchorKey
    });

    await persistSelectionState(
      state.activeProject?.id ?? null,
      primarySelection.selectedChapterId,
      primarySelection.selectedSceneId
    );
  },

  toggleChapterExpansion: async (chapterId) => {
    const state = get();
    const projectId = state.activeProject?.id;
    if (!projectId) {
      return;
    }

    const expanded = state.expandedChapterIds.includes(chapterId)
      ? state.expandedChapterIds.filter((id) => id !== chapterId)
      : [...state.expandedChapterIds, chapterId];

    set({ expandedChapterIds: expanded });

    await persistWorkspaceSession((current) => ({
      ...current,
      expandedChapterIdsByProject: {
        ...current.expandedChapterIdsByProject,
        [projectId]: expanded
      }
    }));
    await get().refreshSyncState();
  },

  reorderChaptersInActiveProject: async (orderedChapterIds) => {
    const state = get();
    const projectId = state.activeProject?.id;
    if (!projectId || orderedChapterIds.length !== state.chapters.length) {
      return;
    }

    await reorderChapters(projectId, orderedChapterIds);

    const reorderedChapters = orderedChapterIds
      .map((chapterId, index) => {
        const chapter = state.chapters.find((entry) => entry.id === chapterId);
        return chapter ? { ...chapter, order: index } : null;
      })
      .filter((chapter): chapter is ChapterRecord => Boolean(chapter));

    set({
      chapters: reorderedChapters,
      scenes: sortScenesByChapterOrder(reorderedChapters, state.scenes)
    });

    await get().refreshSyncState();
  },

  moveSceneInBinder: async (sceneId, targetChapterId, targetOrder) => {
    const state = get();
    const movedScene = state.scenes.find((scene) => scene.id === sceneId);
    if (!movedScene) {
      return;
    }

    await moveSceneToChapterPosition(sceneId, targetChapterId, targetOrder);

    const remainingScenes = state.scenes.filter((scene) => scene.id !== sceneId);
    const targetChapterScenes = remainingScenes
      .filter((scene) => scene.chapterId === targetChapterId)
      .sort((left, right) => left.order - right.order);
    const insertionIndex = Math.max(0, Math.min(targetOrder, targetChapterScenes.length));
    const movedSceneLocal = {
      ...movedScene,
      chapterId: targetChapterId
    };
    targetChapterScenes.splice(insertionIndex, 0, movedSceneLocal);

    const nextScenes = remainingScenes.map((scene) => {
      if (scene.chapterId === movedScene.chapterId && movedScene.chapterId !== targetChapterId) {
        const sourceOrder = remainingScenes
          .filter((entry) => entry.chapterId === movedScene.chapterId)
          .sort((left, right) => left.order - right.order)
          .findIndex((entry) => entry.id === scene.id);
        return {
          ...scene,
          order: sourceOrder
        };
      }

      return scene;
    }).map((scene) => {
      if (scene.chapterId !== targetChapterId) {
        return scene;
      }

      const nextOrder = targetChapterScenes.findIndex((entry) => entry.id === scene.id);
      if (nextOrder === -1) {
        return scene;
      }

      return {
        ...scene,
        chapterId: targetChapterId,
        order: nextOrder
      };
    });

    if (!nextScenes.some((scene) => scene.id === movedScene.id)) {
      nextScenes.push({
        ...movedSceneLocal,
        order: insertionIndex
      });
    }

    const sortedScenes = sortScenesByChapterOrder(
      state.chapters,
      nextScenes
    );
    const nextSelectedChapterId = state.selectedSceneId === sceneId
      ? targetChapterId
      : state.selectedChapterId;
    const nextSelectedSceneIds = state.selectedSceneId
      ? [state.selectedSceneId === sceneId ? sceneId : state.selectedSceneId]
      : nextSelectedChapterId
        ? sortedScenes
            .filter((scene) => scene.chapterId === nextSelectedChapterId)
            .map((scene) => scene.id)
        : [];
    const nextSelectedChapterIds = nextSelectedChapterId ? [nextSelectedChapterId] : [];

    set({
      scenes: sortedScenes,
      selectedChapterId: nextSelectedChapterId,
      selectedChapterIds: nextSelectedChapterIds,
      selectedSceneIds: nextSelectedSceneIds
    });

    if (state.selectedSceneId === sceneId) {
      await persistSelectionState(state.activeProject?.id ?? null, targetChapterId, sceneId);
    }
    await get().refreshSyncState();
  },

  renameProject: async (projectId, title) => {
    const trimmedTitle = title.trim();
    if (!trimmedTitle) {
      return;
    }

    await updateProjectTitle(projectId, trimmedTitle);
    const updatedAt = nowIso();

    set((state) => ({
      projects: patchProjectListItem(state.projects, projectId, {
        title: trimmedTitle,
        updatedAt
      }),
      activeProject:
        state.activeProject?.id === projectId
          ? { ...state.activeProject, title: trimmedTitle, updatedAt }
          : state.activeProject
    }));
    await get().refreshSyncState();
  },

  renameChapter: async (chapterId, title) => {
    const trimmedTitle = title.trim();
    if (!trimmedTitle) {
      return;
    }

    await updateChapterTitle(chapterId, trimmedTitle);
    const updatedAt = nowIso();

    set((state) => ({
      chapters: state.chapters.map((chapter) =>
        chapter.id === chapterId
          ? { ...chapter, title: trimmedTitle, updatedAt }
          : chapter
      ),
      projects: state.activeProject
        ? patchProjectListItem(state.projects, state.activeProject.id, {
            updatedAt
          })
        : state.projects,
      activeProject: state.activeProject
        ? { ...state.activeProject, updatedAt }
        : state.activeProject
    }));
    await get().refreshSyncState();
  },

  renameScene: async (sceneId, title) => {
    const trimmedTitle = title.trim();
    if (!trimmedTitle) {
      return;
    }

    await updateSceneTitle(sceneId, trimmedTitle);
    const updatedAt = nowIso();

    set((state) => ({
      scenes: state.scenes.map((scene) =>
        scene.id === sceneId
          ? { ...scene, title: trimmedTitle, updatedAt, revision: scene.revision + 1 }
          : scene
      ),
      projects: state.activeProject
        ? patchProjectListItem(state.projects, state.activeProject.id, {
            updatedAt
          })
        : state.projects,
      activeProject: state.activeProject
        ? { ...state.activeProject, updatedAt }
        : state.activeProject
    }));
    await get().refreshSyncState();
  },

  deleteChapterById: async (chapterId) => {
    const state = get();
    const projectId = state.activeProject?.id;
    if (!projectId) {
      return;
    }

    const deletedChapter = state.chapters.find((chapter) => chapter.id === chapterId) ?? null;
    if (!deletedChapter) {
      return;
    }
    const deletedScenes = state.scenes
      .filter((scene) => scene.chapterId === chapterId)
      .sort((left, right) => left.order - right.order);

    const remainingChapters = state.chapters.filter((chapter) => chapter.id !== chapterId);
    const remainingScenes = state.scenes.filter((scene) => scene.chapterId !== chapterId);
    const deletedWasSelected =
      state.selectedChapterId === chapterId ||
      (state.selectedSceneId !== null &&
        state.scenes.find((scene) => scene.id === state.selectedSceneId)?.chapterId === chapterId);

    const fallbackChapter =
      remainingChapters.find((chapter) => chapter.order > deletedChapter.order) ??
      remainingChapters[remainingChapters.length - 1] ??
      null;
    const fallbackScene = fallbackChapter
      ? remainingScenes.find((scene) => scene.chapterId === fallbackChapter.id) ?? null
      : null;
    const nextSelectedChapterId = deletedWasSelected
      ? fallbackChapter?.id ?? null
      : state.selectedChapterId;
    const nextSelectedSceneId = deletedWasSelected
      ? fallbackScene?.id ?? null
      : state.selectedSceneId;

    const trashItem = await moveChapterToTrash(chapterId);
    if (!trashItem) {
      return;
    }

    const nextExpanded = state.expandedChapterIds.filter((id) => id !== chapterId);
    const updatedAt = nowIso();
    clearPendingDeletionTimer(state.pendingDeletionUndo);
    const timeoutId = window.setTimeout(() => {
      get().clearPendingDeletionUndo();
    }, 5000);
    set({
      chapters: remainingChapters,
      scenes: remainingScenes,
      selectedChapterId: nextSelectedChapterId,
      selectedSceneId: nextSelectedSceneId,
      selectedChapterIds: nextSelectedChapterId ? [nextSelectedChapterId] : [],
      selectedSceneIds: nextSelectedSceneId
        ? [nextSelectedSceneId]
        : nextSelectedChapterId
          ? remainingScenes
              .filter((scene) => scene.chapterId === nextSelectedChapterId)
              .map((scene) => scene.id)
          : [],
      selectionAnchorKey:
        nextSelectedSceneId
          ? toBinderItemKey("scene", nextSelectedSceneId)
          : nextSelectedChapterId
            ? toBinderItemKey("chapter", nextSelectedChapterId)
            : null,
      expandedChapterIds: nextExpanded,
      projects: patchProjectListItem(state.projects, projectId, {
        updatedAt
      }),
      activeProject: state.activeProject
        ? { ...state.activeProject, updatedAt }
        : state.activeProject,
      trashItems: sortTrashByDeletedAt([...state.trashItems, trashItem]),
      pendingDeletionUndo: {
        kind: "chapter",
        message: "Chapter deleted.",
        trashItemId: trashItem.id,
        chapter: deletedChapter,
        scenes: deletedScenes,
        timeoutId
      }
    });

    await persistWorkspaceSession((current) => ({
      ...current,
      lastProjectId: projectId,
      lastChapterId: nextSelectedChapterId,
      lastSceneId: nextSelectedSceneId,
      expandedChapterIdsByProject: {
        ...current.expandedChapterIdsByProject,
        [projectId]: nextExpanded
      }
    }));
    await get().refreshSyncState();
  },

  deleteSceneById: async (sceneId) => {
    const state = get();
    const projectId = state.activeProject?.id;
    if (!projectId) {
      return;
    }

    const deletedScene = state.scenes.find((scene) => scene.id === sceneId) ?? null;
    if (!deletedScene) {
      return;
    }

    const siblingScenes = state.scenes
      .filter((scene) => scene.chapterId === deletedScene.chapterId && scene.id !== sceneId)
      .sort((left, right) => left.order - right.order);
    const remainingScenes = state.scenes.filter((scene) => scene.id !== sceneId);
    const fallbackScene =
      siblingScenes.find((scene) => scene.order > deletedScene.order) ??
      siblingScenes[siblingScenes.length - 1] ??
      remainingScenes[0] ??
      null;
    const fallbackChapterId =
      fallbackScene?.chapterId ??
      state.chapters.find((chapter) => chapter.id === deletedScene.chapterId)?.id ??
      state.chapters[0]?.id ??
      null;
    const deletedWasSelected = state.selectedSceneId === sceneId;
    const nextSelectedChapterId = deletedWasSelected
      ? fallbackChapterId
      : state.selectedChapterId;
    const nextSelectedSceneId = deletedWasSelected
      ? fallbackScene?.id ?? null
      : state.selectedSceneId;

    const trashItem = await moveSceneToTrash(sceneId);
    if (!trashItem) {
      return;
    }

    const updatedAt = nowIso();
    clearPendingDeletionTimer(state.pendingDeletionUndo);
    const timeoutId = window.setTimeout(() => {
      get().clearPendingDeletionUndo();
    }, 5000);
    set({
      scenes: remainingScenes,
      selectedChapterId: nextSelectedChapterId,
      selectedSceneId: nextSelectedSceneId,
      selectedChapterIds: nextSelectedChapterId ? [nextSelectedChapterId] : [],
      selectedSceneIds: nextSelectedSceneId
        ? [nextSelectedSceneId]
        : nextSelectedChapterId
          ? remainingScenes
              .filter((scene) => scene.chapterId === nextSelectedChapterId)
              .map((scene) => scene.id)
          : [],
      selectionAnchorKey:
        nextSelectedSceneId
          ? toBinderItemKey("scene", nextSelectedSceneId)
          : nextSelectedChapterId
            ? toBinderItemKey("chapter", nextSelectedChapterId)
            : null,
      projects: patchProjectListItem(state.projects, projectId, {
        updatedAt
      }),
      activeProject: state.activeProject
        ? { ...state.activeProject, updatedAt }
        : state.activeProject,
      trashItems: sortTrashByDeletedAt([...state.trashItems, trashItem]),
      pendingDeletionUndo: {
        kind: "scene",
        message: "Scene deleted.",
        trashItemId: trashItem.id,
        scene: deletedScene,
        timeoutId
      }
    });

    await persistSelectionState(
      projectId,
      nextSelectedChapterId,
      nextSelectedSceneId
    );
    await get().refreshSyncState();
  },

  undoPendingDeletion: async () => {
    const state = get();
    const pending = state.pendingDeletionUndo;
    if (!pending) {
      return;
    }

    clearPendingDeletionTimer(pending);

    if (pending.kind === "project") {
      const restoredItem = await restoreTrashItem(pending.trashItemId);
      if (!restoredItem) {
        set({ pendingDeletionUndo: null });
        return;
      }

      const restoredProject = (restoredItem.payload as { project: ProjectRecord }).project;
      set({
        projects: [restoredProject, ...state.projects].sort((left, right) => right.updatedAt.localeCompare(left.updatedAt)),
        projectTrashItems: state.projectTrashItems.filter((entry) => entry.id !== pending.trashItemId),
        pendingDeletionUndo: null
      });
      await get().refreshSyncState();
      return;
    }

    const projectId = state.activeProject?.id;
    if (!projectId) {
      return;
    }

    if (pending.kind === "scene") {
      const restoredItem = await restoreTrashItem(pending.trashItemId);
      if (!restoredItem) {
        set({ pendingDeletionUndo: null });
        return;
      }
      const restoredScene = (restoredItem.payload as { scene: SceneRecord }).scene;
      const requiresReload = !state.chapters.some((chapter) => chapter.id === restoredScene.chapterId);
      if (requiresReload) {
        await get().loadProject(projectId, {
          preferredChapterId: restoredScene.chapterId,
          preferredSceneId: restoredScene.id,
          skipLoadingState: true
        });
        set((current) => ({
          trashItems: current.trashItems.filter((entry) => entry.id !== pending.trashItemId),
          pendingDeletionUndo: null
        }));
        await persistSelectionState(projectId, restoredScene.chapterId, restoredScene.id);
        await get().refreshSyncState();
        return;
      }
      const nextScenes = [...state.scenes, restoredScene].sort((left, right) => {
        if (left.chapterId === right.chapterId) {
          return left.order - right.order;
        }

        return left.chapterId.localeCompare(right.chapterId);
      });

      set({
        scenes: nextScenes,
        selectedChapterId: restoredScene.chapterId,
        selectedSceneId: restoredScene.id,
        selectedChapterIds: [restoredScene.chapterId],
        selectedSceneIds: [restoredScene.id],
        selectionAnchorKey: toBinderItemKey("scene", restoredScene.id),
        trashItems: state.trashItems.filter((entry) => entry.id !== pending.trashItemId),
        pendingDeletionUndo: null
      });

      await persistSelectionState(projectId, restoredScene.chapterId, restoredScene.id);
      await get().refreshSyncState();
      return;
    }

    const restoredItem = await restoreTrashItem(pending.trashItemId);
    if (!restoredItem) {
      set({ pendingDeletionUndo: null });
      return;
    }
    const restoredChapter = (restoredItem.payload as { chapter: ChapterRecord; scenes: SceneRecord[] }).chapter;
    const restoredScenes = (restoredItem.payload as { chapter: ChapterRecord; scenes: SceneRecord[] }).scenes;
    const nextChapters = [...state.chapters, restoredChapter].sort((left, right) => left.order - right.order);
    const nextScenes = [...state.scenes, ...restoredScenes].sort((left, right) => {
      if (left.chapterId === right.chapterId) {
        return left.order - right.order;
      }

      const leftChapterOrder = nextChapters.find((chapter) => chapter.id === left.chapterId)?.order ?? Number.MAX_SAFE_INTEGER;
      const rightChapterOrder = nextChapters.find((chapter) => chapter.id === right.chapterId)?.order ?? Number.MAX_SAFE_INTEGER;
      if (leftChapterOrder !== rightChapterOrder) {
        return leftChapterOrder - rightChapterOrder;
      }

      return left.order - right.order;
    });
    const restoredSceneIds = restoredScenes.map((scene) => scene.id);
    const nextExpanded = state.expandedChapterIds.includes(restoredChapter.id)
      ? state.expandedChapterIds
      : [...state.expandedChapterIds, restoredChapter.id];

    set({
      chapters: nextChapters,
      scenes: nextScenes,
      selectedChapterId: restoredChapter.id,
      selectedSceneId: null,
      selectedChapterIds: [restoredChapter.id],
      selectedSceneIds: restoredSceneIds,
      selectionAnchorKey: toBinderItemKey("chapter", restoredChapter.id),
      expandedChapterIds: nextExpanded,
      trashItems: state.trashItems.filter((entry) => entry.id !== pending.trashItemId),
      pendingDeletionUndo: null
    });

    await persistWorkspaceSession((current) => ({
      ...current,
      lastProjectId: projectId,
      lastChapterId: restoredChapter.id,
      lastSceneId: null,
      expandedChapterIdsByProject: {
        ...current.expandedChapterIdsByProject,
        [projectId]: nextExpanded
      }
    }));
    await get().refreshSyncState();
  },

  clearPendingDeletionUndo: () => {
    set((state) => {
      clearPendingDeletionTimer(state.pendingDeletionUndo);
      return {
        pendingDeletionUndo: null
      };
    });
  },

  restoreTrashItemById: async (trashItemId) => {
    const state = get();
    const trashItem = state.trashItems.find((entry) => entry.id === trashItemId) ?? null;
    const projectId = state.activeProject?.id;
    if (!trashItem || !projectId) {
      return;
    }

    const restoredItem = await restoreTrashItem(trashItemId);
    if (!restoredItem) {
      return;
    }

    if (trashItem.entityType === "scene") {
      const restoredScene = ((restoredItem.payload as { scene: SceneRecord }).scene);
      const requiresReload = !state.chapters.some((chapter) => chapter.id === restoredScene.chapterId);
      if (requiresReload) {
        await get().loadProject(projectId, {
          preferredChapterId: restoredScene.chapterId,
          preferredSceneId: restoredScene.id,
          skipLoadingState: true
        });
        set((current) => ({
          trashItems: current.trashItems.filter((entry) => entry.id !== trashItemId)
        }));
        await persistSelectionState(projectId, restoredScene.chapterId, restoredScene.id);
        await get().refreshSyncState();
        return;
      }
      const nextScenes = sortScenesByChapterOrder(state.chapters, [...state.scenes, restoredScene]);

      set({
        scenes: nextScenes,
        trashItems: state.trashItems.filter((entry) => entry.id !== trashItemId),
        selectedChapterId: restoredScene.chapterId,
        selectedSceneId: restoredScene.id,
        selectedChapterIds: [restoredScene.chapterId],
        selectedSceneIds: [restoredScene.id],
        selectionAnchorKey: toBinderItemKey("scene", restoredScene.id)
      });

      await persistSelectionState(projectId, restoredScene.chapterId, restoredScene.id);
      await get().refreshSyncState();
      return;
    }

    const restoredChapter = (trashItem.payload as { chapter: ChapterRecord; scenes: SceneRecord[] }).chapter;
    const restoredScenes = (trashItem.payload as { chapter: ChapterRecord; scenes: SceneRecord[] }).scenes;
    const nextChapters = [...state.chapters, restoredChapter].sort((left, right) => left.order - right.order);
    const nextScenes = sortScenesByChapterOrder(nextChapters, [...state.scenes, ...restoredScenes]);
    const nextExpanded = state.expandedChapterIds.includes(restoredChapter.id)
      ? state.expandedChapterIds
      : [...state.expandedChapterIds, restoredChapter.id];

    set({
      chapters: nextChapters,
      scenes: nextScenes,
      trashItems: state.trashItems.filter((entry) => entry.id !== trashItemId),
      expandedChapterIds: nextExpanded,
      selectedChapterId: restoredChapter.id,
      selectedSceneId: null,
      selectedChapterIds: [restoredChapter.id],
      selectedSceneIds: restoredScenes.map((scene) => scene.id),
      selectionAnchorKey: toBinderItemKey("chapter", restoredChapter.id)
    });

    await persistWorkspaceSession((current) => ({
      ...current,
      lastProjectId: projectId,
      lastChapterId: restoredChapter.id,
      lastSceneId: null,
      expandedChapterIdsByProject: {
        ...current.expandedChapterIdsByProject,
        [projectId]: nextExpanded
      }
    }));
    await get().refreshSyncState();
  },

  restoreProjectTrashItemById: async (trashItemId) => {
    const state = get();
    const trashItem = state.projectTrashItems.find((entry) => entry.id === trashItemId) ?? null;
    if (!trashItem) {
      return;
    }

    const restoredItem = await restoreTrashItem(trashItemId);
    if (!restoredItem) {
      return;
    }

    const restoredProject = (restoredItem.payload as { project: ProjectRecord }).project;
    set({
      projects: [restoredProject, ...state.projects].sort((left, right) => right.updatedAt.localeCompare(left.updatedAt)),
      projectTrashItems: state.projectTrashItems.filter((entry) => entry.id !== trashItemId)
    });
    await get().refreshSyncState();
  },

  permanentlyDeleteTrashItemById: async (trashItemId) => {
    const state = get();
    await permanentlyDeleteTrashItem(trashItemId);

    if (state.pendingDeletionUndo?.trashItemId === trashItemId) {
      clearPendingDeletionTimer(state.pendingDeletionUndo);
    }

    set({
      trashItems: state.trashItems.filter((entry) => entry.id !== trashItemId),
      pendingDeletionUndo:
        state.pendingDeletionUndo?.trashItemId === trashItemId
          ? null
          : state.pendingDeletionUndo
    });
  },

  permanentlyDeleteProjectTrashItemById: async (trashItemId) => {
    const state = get();
    await permanentlyDeleteTrashItem(trashItemId);

    if (state.pendingDeletionUndo?.trashItemId === trashItemId) {
      clearPendingDeletionTimer(state.pendingDeletionUndo);
    }

    set({
      projectTrashItems: state.projectTrashItems.filter((entry) => entry.id !== trashItemId),
      pendingDeletionUndo:
        state.pendingDeletionUndo?.trashItemId === trashItemId
          ? null
          : state.pendingDeletionUndo
    });
  },

  updateSceneDraftLocal: (sceneId, contentJson) => {
    const sanitizedContent = sanitizeRichTextContent(contentJson);
    const metrics = getTextMetrics(sanitizedContent);
    set((state) => ({
      scenes: state.scenes.map((scene) =>
        scene.id === sceneId
          ? {
              ...scene,
              contentJson: sanitizedContent,
              contentText: metrics.plainText,
              wordCount: metrics.wordCount,
              characterCount: metrics.characterCount
            }
          : scene
      )
    }));
  },

  saveSceneDraft: async (sceneId, contentJson) => {
    const sanitizedContent = sanitizeRichTextContent(contentJson);
    const metrics = getTextMetrics(sanitizedContent);
    const queuedSave = (sceneSaveQueues.get(sceneId) ?? Promise.resolve()).then(async () => {
      await updateSceneContent(
        sceneId,
        sanitizedContent,
        metrics.plainText,
        metrics.wordCount,
        metrics.characterCount
      );
      const updatedAt = nowIso();
      set((state) => ({
        scenes: state.scenes.map((scene) =>
          scene.id === sceneId
            ? {
                ...scene,
                contentJson: sanitizedContent,
                contentText: metrics.plainText,
                wordCount: metrics.wordCount,
                characterCount: metrics.characterCount,
                revision: scene.revision + 1,
                updatedAt
              }
            : scene
        ),
        projects: state.activeProject
          ? patchProjectListItem(state.projects, state.activeProject.id, {
              updatedAt
            })
          : state.projects,
        activeProject: state.activeProject
          ? { ...state.activeProject, updatedAt }
          : state.activeProject
      }));
    });

    const queuePromise = queuedSave.finally(() => {
      if (sceneSaveQueues.get(sceneId) === queuePromise) {
        sceneSaveQueues.delete(sceneId);
      }
    });

    sceneSaveQueues.set(sceneId, queuePromise);

    await queuedSave;
    await get().refreshSyncState();
  },

  saveSceneEditorState: async (sceneId, cursorFrom, cursorTo, scrollTop) => {
    await saveSceneEditorSession({
      sceneId,
      cursorFrom,
      cursorTo,
      scrollTop,
      updatedAt: nowIso()
    });
  },

  getSceneEditorState: async (sceneId) => {
    const session = await getSceneEditorSession(sceneId);
    if (!session) {
      return null;
    }

    return {
      cursorFrom: session.cursorFrom,
      cursorTo: session.cursorTo,
      scrollTop: session.scrollTop
    };
  },

  setEditorZoom: async (zoomPercent) => {
    const normalizedZoom = Math.min(160, Math.max(80, zoomPercent));
    set({ editorZoomPercent: normalizedZoom });
    await persistWorkspaceSession((current) => ({
      ...current,
      editorZoomPercent: normalizedZoom
    }));
  },

  setAuthMode: async (mode) => {
    set({ authMode: mode });
    await persistWorkspaceSession((current) => ({
      ...defaultWorkspaceSession,
      ...current,
      authMode: mode
    }));
    await get().refreshProjects();
    await get().refreshSyncState();
  },

  setCurrentUser: async (user) => {
    const state = get();
    if (
      (state.currentUser === null && user === null) ||
      (state.currentUser !== null &&
        user !== null &&
        state.currentUser.id === user.id &&
        state.currentUser.email === user.email)
    ) {
      return;
    }

    if (state.authMode === "supabase" && user) {
      await claimAnonymousProjectsForUser(user.id);
    }

    set({ currentUser: user });

    if (state.authMode === "supabase") {
      const accessOptions = getProjectAccessOptions({
        ...get(),
        currentUser: user
      });
      const [projects, projectTrashItems] = await Promise.all([
        listProjects(accessOptions),
        listProjectTrashItems(accessOptions)
      ]);
      const visibleProjects = filterProjectsAgainstTrash(projects, projectTrashItems);
      const activeProjectId = get().activeProject?.id ?? null;
      const shouldKeepActive = activeProjectId
        ? visibleProjects.some((project) => project.id === activeProjectId)
        : false;

      set({
        projects: visibleProjects,
        projectTrashItems,
        ...(shouldKeepActive
          ? {}
          : {
              activeProject: null,
              chapters: [],
              scenes: [],
              trashItems: [],
              selectedChapterId: null,
              selectedSceneId: null,
              selectedChapterIds: [],
              selectedSceneIds: [],
              selectionAnchorKey: null,
              expandedChapterIds: []
            })
      });
    }

    await get().refreshSyncState();
  },

  completeSupabaseAuth: async () => {
    const user = await getSupabaseAuthUser();
    set({ authMode: "supabase" });
    await persistWorkspaceSession((current) => ({
      ...defaultWorkspaceSession,
      ...current,
      authMode: "supabase"
    }));
    await get().setCurrentUser(user);
  },

  signOutToSupabaseMode: async () => {
    set({
      currentUser: null,
      activeProject: null,
      chapters: [],
      scenes: [],
      projectTrashItems: [],
      trashItems: [],
      selectedChapterId: null,
      selectedSceneId: null,
      selectedChapterIds: [],
      selectedSceneIds: [],
      selectionAnchorKey: null,
      expandedChapterIds: [],
      projects: []
    });
    await persistWorkspaceSession((current) => ({
      ...defaultWorkspaceSession,
      ...current,
      authMode: "supabase",
      lastProjectId: null,
      lastChapterId: null,
      lastSceneId: null
    }));
    await get().refreshSyncState();
  }
}));

function resolveGlobalSyncStatus(input: {
  isOnline: boolean;
  pendingSyncCount: number;
  conflictCount: number;
  isSyncing: boolean;
  syncMessage: string | null;
}): SyncStatus {
  if (!input.isOnline) {
    return "offline";
  }

  if (input.isSyncing) {
    return "syncing";
  }

  if (input.conflictCount > 0) {
    return "conflict";
  }

  if (input.syncMessage) {
    return "sync_failed";
  }

  if (input.pendingSyncCount > 0) {
    return "saved_locally";
  }

  return "synced";
}

async function runSync(
  get: () => AppStoreState,
  set: (partial: Partial<AppStoreState>) => void,
  force: boolean
): Promise<void> {
  const state = get();
  if (state.authMode !== "supabase" || !state.currentUser) {
    await state.refreshSyncState();
    return;
  }

  if (!state.isOnline) {
    set({ syncStatus: "offline" });
    return;
  }

  if (state.isSyncing && !force) {
    return;
  }

  set({
    isSyncing: true,
    syncMessage: null,
    syncStatus: "syncing"
  });

  try {
    const summary = await runSyncCycle();
    await get().refreshProjects();

    await get().refreshSyncState();
    const next = get();
    set({
      isSyncing: false,
      lastSyncAt: nowIso(),
      syncMessage: summary.failed > 0 ? "Some changes could not be synced." : null,
      syncStatus: resolveGlobalSyncStatus({
        isOnline: next.isOnline,
        pendingSyncCount: next.pendingSyncCount,
        conflictCount: next.conflictCount,
        isSyncing: false,
        syncMessage: summary.failed > 0 ? "Some changes could not be synced." : null
      })
    });
  } catch (error) {
    set({
      isSyncing: false,
      syncMessage: error instanceof Error ? error.message : "Sync failed",
      syncStatus: "sync_failed"
    });
  }
}
