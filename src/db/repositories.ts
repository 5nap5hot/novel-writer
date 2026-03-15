import { db } from "./database";
import { getWorkspaceSession, saveWorkspaceSession } from "./session";
import { createId } from "../lib/id";
import { nowIso } from "../lib/time";
import { getSupabaseClient } from "../lib/supabase";
import {
  EMPTY_DOCUMENT,
  getTextMetrics,
  normalizeRichTextContent,
  sanitizeRichTextContent
} from "../lib/editorContent";
import type {
  ChapterRecord,
  ConflictState,
  DeviceIdentity,
  EntityType,
  ProjectRecord,
  RemoteChapterRow,
  RemoteProjectRow,
  RemoteSceneRow,
  RichTextContent,
  SceneEditorSession,
  SceneRecord,
  SyncQueueEntry,
  SyncStatus,
  TrashItemRecord,
  WorkspaceSession
} from "../types/models";

const DEVICE_IDENTITY_KEY = "device-identity";
const DELETED_PROJECT_TOMBSTONES_KEY = "deleted-project-tombstones";

export interface ProjectBundle {
  project: ProjectRecord;
  chapters: ChapterRecord[];
  scenes: SceneRecord[];
}

export interface SeededProjectBundle extends ProjectBundle {
  initialChapter: ChapterRecord;
  initialScene: SceneRecord;
}

export interface ProjectSummary {
  projectId: string;
  chapterCount: number;
  wordCount: number;
}

interface ProjectAccessOptions {
  ownerUserId?: string | null;
  includeAnonymous?: boolean;
}

function sortTrashItems(items: TrashItemRecord[]): TrashItemRecord[] {
  return [...items].sort((left, right) => right.deletedAt.localeCompare(left.deletedAt));
}

function getProjectFingerprint(project: Pick<ProjectRecord, "title" | "createdAt">): string {
  return `${project.title}::${project.createdAt}`;
}

async function getDeletedProjectTombstones(): Promise<{ ids: string[]; fingerprints: string[] }> {
  const record = await db.appState.get(DELETED_PROJECT_TOMBSTONES_KEY);
  const value = (record?.value as { ids?: string[]; fingerprints?: string[] } | undefined) ?? {};
  return {
    ids: value.ids ?? [],
    fingerprints: value.fingerprints ?? []
  };
}

async function addDeletedProjectTombstone(project: Pick<ProjectRecord, "id" | "title" | "createdAt">): Promise<void> {
  const current = await getDeletedProjectTombstones();
  await db.appState.put({
    key: DELETED_PROJECT_TOMBSTONES_KEY,
    value: {
      ids: Array.from(new Set([...current.ids, project.id])),
      fingerprints: Array.from(new Set([...current.fingerprints, getProjectFingerprint(project)]))
    }
  });
}

export async function getDeletedProjectTombstonesSnapshot(): Promise<{ ids: string[]; fingerprints: string[] }> {
  return getDeletedProjectTombstones();
}

function createSyncDefaults(deviceId: string): Pick<
  ProjectRecord,
  "lastEditedDeviceId" | "lastSyncedAt" | "remoteUpdatedAt" | "syncError" | "syncStatus"
> {
  return {
    lastEditedDeviceId: deviceId,
    lastSyncedAt: null,
    remoteUpdatedAt: null,
    syncError: null,
    syncStatus: "saved_locally"
  };
}

function createSceneSyncDefaults(deviceId: string): Pick<
  SceneRecord,
  | "lastEditedDeviceId"
  | "lastSyncedAt"
  | "remoteUpdatedAt"
  | "remoteRevision"
  | "syncError"
  | "syncStatus"
  | "conflictState"
  | "conflictGroupId"
  | "remoteOriginalId"
  | "syncSuppressed"
> {
  return {
    ...createSyncDefaults(deviceId),
    remoteRevision: null,
    conflictState: "none",
    conflictGroupId: null,
    remoteOriginalId: null,
    syncSuppressed: false
  };
}

function createQueueEntry(
  entityType: EntityType,
  entityId: string,
  entityRevision: number | null
): SyncQueueEntry {
  const timestamp = nowIso();
  return {
    id: createId("queue"),
    dedupeKey: `${entityType}:${entityId}:upsert`,
    entityType,
    entityId,
    entityRevision,
    operation: "upsert",
    createdAt: timestamp,
    updatedAt: timestamp,
    attemptCount: 0,
    lastAttemptAt: null,
    lastError: null
  };
}

async function enqueueUpsert(
  entityType: EntityType,
  entityId: string,
  entityRevision: number | null = null
): Promise<void> {
  const existing = await db.syncQueue.where("dedupeKey").equals(`${entityType}:${entityId}:upsert`).first();
  if (existing) {
    await db.syncQueue.update(existing.id, {
      entityRevision,
      updatedAt: nowIso(),
      lastError: null
    });
    return;
  }

  await db.syncQueue.add(createQueueEntry(entityType, entityId, entityRevision));
}

async function clearQueuedUpsert(entityType: EntityType, entityId: string): Promise<void> {
  const existing = await db.syncQueue.where("dedupeKey").equals(`${entityType}:${entityId}:upsert`).first();
  if (existing) {
    await db.syncQueue.delete(existing.id);
  }
}

async function updateSceneRecord(sceneId: string, changes: unknown): Promise<void> {
  await (db.table("scenes") as { update: (id: string, changes: unknown) => Promise<number> }).update(sceneId, changes);
}

function sortScenes(items: SceneRecord[]): SceneRecord[] {
  return items.sort((left, right) => {
    if (left.chapterId === right.chapterId) {
      return left.order - right.order;
    }

    return left.chapterId.localeCompare(right.chapterId);
  });
}

export async function ensureDeviceIdentity(): Promise<DeviceIdentity> {
  const existing = await db.appState.get(DEVICE_IDENTITY_KEY);
  if (existing?.value) {
    return existing.value as DeviceIdentity;
  }

  const identity: DeviceIdentity = {
    id: createId("device"),
    label: typeof navigator !== "undefined" ? navigator.userAgent.slice(0, 80) : "unknown-device",
    createdAt: nowIso()
  };

  await db.appState.put({
    key: DEVICE_IDENTITY_KEY,
    value: identity
  });

  return identity;
}

export async function listProjects(options: ProjectAccessOptions = {}): Promise<ProjectRecord[]> {
  const trashedProjectItems = (await db.trashItems.toArray()).filter((item) => item.entityType === "project");
  const trashedProjectIds = new Set(trashedProjectItems.map((item) => item.projectId));
  const trashedFingerprints = new Set(
    trashedProjectItems.map((item) => {
      const payload = item.payload as { project?: ProjectRecord };
      const fingerprintSource = payload.project ?? {
        title: item.title,
        createdAt: item.deletedAt
      };
      return getProjectFingerprint(fingerprintSource as Pick<ProjectRecord, "title" | "createdAt">);
    })
  );
  const tombstones = await getDeletedProjectTombstones();
  const tombstonedIds = new Set(tombstones.ids);
  const tombstonedFingerprints = new Set(tombstones.fingerprints);
  const projects = (await db.projects.orderBy("updatedAt").reverse().toArray())
    .filter((project) =>
      !trashedProjectIds.has(project.id) &&
      !trashedFingerprints.has(getProjectFingerprint(project)) &&
      !tombstonedIds.has(project.id) &&
      !tombstonedFingerprints.has(getProjectFingerprint(project))
    );
  const ownerUserId = options.ownerUserId;

  if (ownerUserId === undefined) {
    return projects;
  }

  if (ownerUserId === null) {
    return projects.filter((project) => project.ownerUserId === null);
  }

  return projects.filter((project) =>
    project.ownerUserId === ownerUserId || (options.includeAnonymous && project.ownerUserId === null)
  );
}

export async function getProjectBundle(
  projectId: string,
  options: ProjectAccessOptions = {}
): Promise<ProjectBundle | null> {
  const project = await db.projects.get(projectId);
  if (!project) {
    return null;
  }

  const trashedProject = await db.trashItems
    .toArray()
    .then((items) => items.filter((item) => item.entityType === "project"));
  const isProjectTrashed = trashedProject.some((item) => item.projectId === projectId);
  const projectFingerprint = getProjectFingerprint(project);
  const isFingerprintTrashed = trashedProject.some((item) => {
    const payload = item.payload as { project?: ProjectRecord };
    return payload.project ? getProjectFingerprint(payload.project) === projectFingerprint : false;
  });
  if (isProjectTrashed || isFingerprintTrashed) {
    return null;
  }

  const tombstones = await getDeletedProjectTombstones();
  if (tombstones.ids.includes(projectId) || tombstones.fingerprints.includes(projectFingerprint)) {
    return null;
  }

  const ownerUserId = options.ownerUserId;
  if (ownerUserId !== undefined) {
    const isAllowed =
      ownerUserId === null
        ? project.ownerUserId === null
        : project.ownerUserId === ownerUserId || (options.includeAnonymous && project.ownerUserId === null);

    if (!isAllowed) {
      return null;
    }
  }

  const chapters = await db.chapters.where("projectId").equals(projectId).sortBy("order");
  const scenes = await db.scenes
    .where("projectId")
    .equals(projectId)
    .toArray()
    .then((items) =>
      sortScenes(items).map((scene) => {
        const contentJson = sanitizeRichTextContent(normalizeRichTextContent(scene));
        const metrics = getTextMetrics(contentJson);

        return {
          ...scene,
          contentJson,
          contentText: scene.contentText ?? metrics.plainText,
          wordCount: scene.wordCount ?? metrics.wordCount,
          characterCount: scene.characterCount ?? metrics.characterCount,
          revision: scene.revision ?? 1,
          remoteRevision: scene.remoteRevision ?? null
        };
      })
    );

  return { project, chapters, scenes };
}

export async function listTrashItems(projectId: string): Promise<TrashItemRecord[]> {
  const items = await db.trashItems.where("projectId").equals(projectId).toArray();
  return sortTrashItems(items);
}

export async function listProjectTrashItems(options: ProjectAccessOptions = {}): Promise<TrashItemRecord[]> {
  const items = (await db.trashItems.toArray()).filter((item) => item.entityType === "project");
  const ownerUserId = options.ownerUserId;

  if (ownerUserId === undefined) {
    return sortTrashItems(items);
  }

  if (ownerUserId === null) {
    return sortTrashItems(items.filter((item) => item.ownerUserId === null));
  }

  return sortTrashItems(items.filter((item) =>
    item.ownerUserId === ownerUserId || (options.includeAnonymous && item.ownerUserId === null)
  ));
}

export async function listProjectSummaries(options: ProjectAccessOptions = {}): Promise<ProjectSummary[]> {
  const projects = await listProjects(options);
  const projectIds = new Set(projects.map((project) => project.id));
  const [chapters, scenes] = await Promise.all([
    db.chapters.toArray(),
    db.scenes.toArray()
  ]);

  return projects.map((project) => ({
    projectId: project.id,
    chapterCount: chapters.filter((chapter) => chapter.projectId === project.id).length,
    wordCount: scenes
      .filter((scene) => scene.projectId === project.id)
      .reduce((sum, scene) => sum + scene.wordCount, 0)
  }));
}

export async function createProject(title = "New Novel", ownerUserId: string | null = null): Promise<ProjectRecord> {
  const device = await ensureDeviceIdentity();
  const timestamp = nowIso();
  const project: ProjectRecord = {
    id: createId("project"),
    ownerUserId,
    title,
    createdAt: timestamp,
    updatedAt: timestamp,
    ...createSyncDefaults(device.id)
  };

  await db.projects.add(project);
  await enqueueUpsert("project", project.id);
  return project;
}

export async function createProjectWithInitialStructure(
  title = "New Novel",
  ownerUserId: string | null = null
): Promise<SeededProjectBundle> {
  const device = await ensureDeviceIdentity();
  const timestamp = nowIso();
  const project: ProjectRecord = {
    id: createId("project"),
    ownerUserId,
    title,
    createdAt: timestamp,
    updatedAt: timestamp,
    ...createSyncDefaults(device.id)
  };
  const initialChapter: ChapterRecord = {
    id: createId("chapter"),
    projectId: project.id,
    title: "Chapter 1",
    order: 0,
    createdAt: timestamp,
    updatedAt: timestamp,
    ...createSyncDefaults(device.id)
  };
  const initialScene: SceneRecord = {
    id: createId("scene"),
    projectId: project.id,
    chapterId: initialChapter.id,
    title: "Scene 1",
    contentJson: EMPTY_DOCUMENT,
    contentText: "",
    wordCount: 0,
    characterCount: 0,
    order: 0,
    revision: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
    ...createSceneSyncDefaults(device.id)
  };

  await db.transaction("rw", db.projects, db.chapters, db.scenes, db.syncQueue, async () => {
    await db.projects.add(project);
    await db.chapters.add(initialChapter);
    await db.scenes.add(initialScene);
    await enqueueUpsert("project", project.id);
    await enqueueUpsert("chapter", initialChapter.id);
    await enqueueUpsert("scene", initialScene.id, initialScene.revision);
  });

  return {
    project,
    chapters: [initialChapter],
    scenes: [initialScene],
    initialChapter,
    initialScene
  };
}

export async function updateProjectTitle(projectId: string, title: string): Promise<void> {
  const device = await ensureDeviceIdentity();
  await db.projects.update(projectId, {
    title,
    updatedAt: nowIso(),
    lastEditedDeviceId: device.id,
    syncError: null,
    syncStatus: "saved_locally"
  });
  await enqueueUpsert("project", projectId);
}

export async function createChapter(
  projectId: string,
  insertAfterOrder?: number | null
): Promise<ChapterRecord> {
  const device = await ensureDeviceIdentity();
  const existing = await db.chapters.where("projectId").equals(projectId).sortBy("order");
  const order = insertAfterOrder == null
    ? existing.length
    : Math.min(insertAfterOrder + 1, existing.length);
  const timestamp = nowIso();
  const chapter: ChapterRecord = {
    id: createId("chapter"),
    projectId,
    title: `Chapter ${order + 1}`,
    order,
    createdAt: timestamp,
    updatedAt: timestamp,
    ...createSyncDefaults(device.id)
  };

  await db.transaction("rw", db.projects, db.chapters, db.syncQueue, async () => {
    if (insertAfterOrder != null) {
      const chaptersToShift = existing.filter((existingChapter) => existingChapter.order >= order);
      for (const existingChapter of chaptersToShift) {
        await db.chapters.update(existingChapter.id, {
          order: existingChapter.order + 1,
          updatedAt: timestamp,
          lastEditedDeviceId: device.id,
          syncError: null,
          syncStatus: "saved_locally"
        });
        await enqueueUpsert("chapter", existingChapter.id);
      }
    }

    await db.chapters.add(chapter);
    await db.projects.update(projectId, {
      updatedAt: timestamp,
      lastEditedDeviceId: device.id,
      syncError: null,
      syncStatus: "saved_locally"
    });
    await enqueueUpsert("chapter", chapter.id);
    await enqueueUpsert("project", projectId);
  });

  return chapter;
}

export async function updateChapterTitle(chapterId: string, title: string): Promise<void> {
  const device = await ensureDeviceIdentity();
  const chapter = await db.chapters.get(chapterId);
  if (!chapter) {
    return;
  }

  const timestamp = nowIso();
  await db.transaction("rw", db.projects, db.chapters, db.syncQueue, async () => {
    await db.chapters.update(chapterId, {
      title,
      updatedAt: timestamp,
      lastEditedDeviceId: device.id,
      syncError: null,
      syncStatus: "saved_locally"
    });
    await db.projects.update(chapter.projectId, {
      updatedAt: timestamp,
      lastEditedDeviceId: device.id,
      syncError: null,
      syncStatus: "saved_locally"
    });
    await enqueueUpsert("chapter", chapterId);
    await enqueueUpsert("project", chapter.projectId);
  });
}

export async function createScene(
  projectId: string,
  chapterId: string,
  insertAfterOrder?: number | null
): Promise<SceneRecord> {
  const device = await ensureDeviceIdentity();
  const existing = await db.scenes.where("chapterId").equals(chapterId).sortBy("order");
  const order = insertAfterOrder == null
    ? existing.length
    : Math.min(insertAfterOrder + 1, existing.length);
  const timestamp = nowIso();
  const scene: SceneRecord = {
    id: createId("scene"),
    projectId,
    chapterId,
    title: `Scene ${order + 1}`,
    contentJson: EMPTY_DOCUMENT,
    contentText: "",
    wordCount: 0,
    characterCount: 0,
    order,
    revision: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
    ...createSceneSyncDefaults(device.id)
  };

  await db.transaction("rw", db.projects, db.scenes, db.syncQueue, async () => {
    if (insertAfterOrder != null) {
      const scenesToShift = existing.filter((existingScene) => existingScene.order >= order);
      for (const existingScene of scenesToShift) {
        const nextRevision = existingScene.revision + 1;
        await updateSceneRecord(existingScene.id, {
          order: existingScene.order + 1,
          revision: nextRevision,
          updatedAt: timestamp,
          lastEditedDeviceId: device.id,
          syncError: null,
          syncStatus: existingScene.syncSuppressed ? existingScene.syncStatus : "saved_locally"
        });
        if (!existingScene.syncSuppressed) {
          await enqueueUpsert("scene", existingScene.id, nextRevision);
        }
      }
    }

    await db.scenes.add(scene);
    await db.projects.update(projectId, {
      updatedAt: timestamp,
      lastEditedDeviceId: device.id,
      syncError: null,
      syncStatus: "saved_locally"
    });
    await enqueueUpsert("scene", scene.id, scene.revision);
    await enqueueUpsert("project", projectId);
  });

  return scene;
}

export async function updateSceneTitle(sceneId: string, title: string): Promise<void> {
  const device = await ensureDeviceIdentity();
  const scene = await db.scenes.get(sceneId);
  if (!scene) {
    return;
  }

  const timestamp = nowIso();
  const nextRevision = scene.revision + 1;
  await db.transaction("rw", db.projects, db.scenes, db.syncQueue, async () => {
    await updateSceneRecord(sceneId, {
      title,
      revision: nextRevision,
      updatedAt: timestamp,
      lastEditedDeviceId: device.id,
      syncError: null,
      syncStatus: scene.syncSuppressed ? scene.syncStatus : "saved_locally"
    });
    await db.projects.update(scene.projectId, {
      updatedAt: timestamp,
      lastEditedDeviceId: device.id,
      syncError: null,
      syncStatus: "saved_locally"
    });
    if (!scene.syncSuppressed) {
      await enqueueUpsert("scene", sceneId, nextRevision);
    }
    await enqueueUpsert("project", scene.projectId);
  });
}

export async function updateSceneContent(
  sceneId: string,
  contentJson: RichTextContent,
  _contentText: string,
  _wordCount: number,
  _characterCount: number
): Promise<void> {
  const device = await ensureDeviceIdentity();
  const scene = await db.scenes.get(sceneId);
  if (!scene) {
    return;
  }

  const timestamp = nowIso();
  const sanitizedContentJson = sanitizeRichTextContent(contentJson);
  const metrics = getTextMetrics(sanitizedContentJson);
  const nextRevision = scene.revision + 1;
  await db.transaction("rw", db.projects, db.scenes, db.syncQueue, async () => {
    await updateSceneRecord(sceneId, {
      contentJson: sanitizedContentJson,
      contentText: metrics.plainText,
      wordCount: metrics.wordCount,
      characterCount: metrics.characterCount,
      revision: nextRevision,
      updatedAt: timestamp,
      lastEditedDeviceId: device.id,
      syncError: null,
      syncStatus: scene.syncSuppressed ? scene.syncStatus : "saved_locally"
    });
    await db.projects.update(scene.projectId, {
      updatedAt: timestamp,
      lastEditedDeviceId: device.id,
      syncError: null,
      syncStatus: "saved_locally"
    });
    if (!scene.syncSuppressed) {
      await enqueueUpsert("scene", sceneId, nextRevision);
    }
    await enqueueUpsert("project", scene.projectId);
  });
}

export async function moveSceneToTrash(sceneId: string): Promise<TrashItemRecord | null> {
  const scene = await db.scenes.get(sceneId);
  if (!scene) {
    return null;
  }
  const chapter = await db.chapters.get(scene.chapterId);

  const device = await ensureDeviceIdentity();
  const timestamp = nowIso();
  const siblingScenes = await db.scenes.where("chapterId").equals(scene.chapterId).sortBy("order");
  const remainingScenes = siblingScenes.filter((entry) => entry.id !== sceneId);
  const trashItem: TrashItemRecord = {
    id: createId("trash"),
    projectId: scene.projectId,
    ownerUserId: (await db.projects.get(scene.projectId))?.ownerUserId ?? null,
    entityType: "scene",
    title: scene.title,
    deletedAt: timestamp,
    originalParentId: scene.chapterId,
    originalParentTitle: chapter?.title ?? null,
    originalIndex: scene.order,
    payload: {
      scene
    }
  };

  await db.transaction("rw", db.projects, db.scenes, db.syncQueue, db.trashItems, async () => {
    for (const [index, sibling] of remainingScenes.entries()) {
      await updateSceneRecord(sibling.id, {
        order: index
      });
      if (!sibling.syncSuppressed) {
        await enqueueUpsert("scene", sibling.id, sibling.revision);
      }
    }

    await db.trashItems.add(trashItem);
    await clearQueuedUpsert("scene", sceneId);
    await db.projects.update(scene.projectId, {
      updatedAt: timestamp,
      lastEditedDeviceId: device.id,
      syncStatus: "saved_locally",
      syncError: null
    });
    await db.scenes.delete(sceneId);
    await enqueueUpsert("project", scene.projectId);
    // Non-destructive v1: local deletions are not pushed remotely.
  });

  return trashItem;
}

export async function moveChapterToTrash(chapterId: string): Promise<TrashItemRecord | null> {
  const chapter = await db.chapters.get(chapterId);
  if (!chapter) {
    return null;
  }

  const device = await ensureDeviceIdentity();
  const timestamp = nowIso();
  const chapterScenes = await db.scenes.where("chapterId").equals(chapterId).sortBy("order");
  const projectChapters = await db.chapters.where("projectId").equals(chapter.projectId).sortBy("order");
  const project = await db.projects.get(chapter.projectId);
  const remainingChapters = projectChapters.filter((entry) => entry.id !== chapterId);
  const trashItem: TrashItemRecord = {
    id: createId("trash"),
    projectId: chapter.projectId,
    ownerUserId: project?.ownerUserId ?? null,
    entityType: "chapter",
    title: chapter.title,
    deletedAt: timestamp,
    originalParentId: null,
    originalParentTitle: null,
    originalIndex: chapter.order,
    payload: {
      chapter,
      scenes: chapterScenes
    }
  };

  const transactionTables = [] as unknown[];
  transactionTables.push(db.projects);
  transactionTables.push(db.chapters);
  transactionTables.push(db.scenes);
  transactionTables.push(db.syncQueue);
  transactionTables.push(db.table("trashItems"));

  await db.transaction("rw", transactionTables as [], async () => {
    for (const [index, siblingChapter] of remainingChapters.entries()) {
      await db.chapters.update(siblingChapter.id, {
        order: index
      });
      await enqueueUpsert("chapter", siblingChapter.id);
    }

    await db.trashItems.add(trashItem);
    await clearQueuedUpsert("chapter", chapterId);
    for (const scene of chapterScenes) {
      await clearQueuedUpsert("scene", scene.id);
    }
    await db.projects.update(chapter.projectId, {
      updatedAt: timestamp,
      lastEditedDeviceId: device.id,
      syncStatus: "saved_locally",
      syncError: null
    });
    await db.scenes.where("chapterId").equals(chapterId).delete();
    await db.chapters.delete(chapterId);
    await enqueueUpsert("project", chapter.projectId);
    // Non-destructive v1: local deletions are not pushed remotely.
  });

  return trashItem;
}

export async function moveProjectToTrash(projectId: string): Promise<TrashItemRecord | null> {
  const project = await db.projects.get(projectId);
  if (!project) {
    return null;
  }

  const chapters = await db.chapters.where("projectId").equals(projectId).sortBy("order");
  const scenes = await db.scenes.where("projectId").equals(projectId).toArray().then(sortScenes);
  const trashItem: TrashItemRecord = {
    id: createId("trash"),
    projectId: project.id,
    ownerUserId: project.ownerUserId,
    entityType: "project",
    title: project.title,
    deletedAt: nowIso(),
    originalParentId: null,
    originalParentTitle: null,
    originalIndex: 0,
    payload: {
      project,
      chapters,
      scenes
    }
  };

  const transactionTables = [] as unknown[];
  transactionTables.push(db.projects);
  transactionTables.push(db.chapters);
  transactionTables.push(db.scenes);
  transactionTables.push(db.syncQueue);
  transactionTables.push(db.trashItems);

  await db.transaction("rw", transactionTables as [], async () => {
    await db.trashItems.add(trashItem);
    await clearQueuedUpsert("project", projectId);
    for (const chapter of chapters) {
      await clearQueuedUpsert("chapter", chapter.id);
    }
    for (const scene of scenes) {
      await clearQueuedUpsert("scene", scene.id);
    }
    await db.scenes.where("projectId").equals(projectId).delete();
    await db.chapters.where("projectId").equals(projectId).delete();
    await db.projects.delete(projectId);
    // Non-destructive v1: local deletions are not pushed remotely.
  });

  return trashItem;
}

export async function restoreTrashItem(trashItemId: string): Promise<TrashItemRecord | null> {
  const device = await ensureDeviceIdentity();
  const timestamp = nowIso();
  const trashItem = await db.trashItems.get(trashItemId);
  if (!trashItem) {
    return null;
  }

  let restoredItem: TrashItemRecord | null = null;

  const transactionTables = [] as unknown[];
  transactionTables.push(db.projects);
  transactionTables.push(db.chapters);
  transactionTables.push(db.scenes);
  transactionTables.push(db.syncQueue);
  transactionTables.push(db.table("trashItems"));

  await db.transaction("rw", transactionTables as [], async () => {
    if (trashItem.entityType === "project") {
      const { project, chapters, scenes } = trashItem.payload as {
        project: ProjectRecord;
        chapters: ChapterRecord[];
        scenes: SceneRecord[];
      };

      await db.projects.put(project);
      await enqueueUpsert("project", project.id);

      for (const chapter of chapters) {
        await db.chapters.put(chapter);
        await enqueueUpsert("chapter", chapter.id);
      }

      for (const scene of scenes) {
        await db.scenes.put(scene);
        if (!scene.syncSuppressed) {
          await enqueueUpsert("scene", scene.id, scene.revision);
        }
      }

      await db.trashItems.delete(trashItemId);
      restoredItem = {
        ...trashItem,
        payload: {
          project,
          chapters,
          scenes
        }
      };
      return;
    }

    if (trashItem.entityType === "scene") {
      const { scene } = trashItem.payload as { scene: SceneRecord };
      let chapters = await db.chapters.where("projectId").equals(trashItem.projectId).sortBy("order");
      let targetChapterId =
        chapters.some((chapter) => chapter.id === trashItem.originalParentId)
          ? trashItem.originalParentId
          : chapters[0]?.id ?? null;

      if (!targetChapterId) {
        const fallbackChapter: ChapterRecord = {
          id: createId("chapter"),
          projectId: trashItem.projectId,
          title: "Recovered Scenes",
          order: 0,
          createdAt: timestamp,
          updatedAt: timestamp,
          ...createSyncDefaults(device.id)
        };
        await db.chapters.put(fallbackChapter);
        await enqueueUpsert("chapter", fallbackChapter.id);
        chapters = [fallbackChapter];
        targetChapterId = fallbackChapter.id;
      }

      const chapterScenes = await db.scenes.where("chapterId").equals(targetChapterId).sortBy("order");
      const insertionIndex = Math.max(0, Math.min(trashItem.originalIndex, chapterScenes.length));
      const reorderedScenes = [...chapterScenes];
      const restoredScene: SceneRecord = {
        ...scene,
        chapterId: targetChapterId,
        order: insertionIndex
      };
      reorderedScenes.splice(insertionIndex, 0, restoredScene);

      for (const [index, entry] of reorderedScenes.entries()) {
        await db.scenes.put({
          ...entry,
          chapterId: targetChapterId,
          order: index
        });
        if (!entry.syncSuppressed) {
          await enqueueUpsert("scene", entry.id, entry.revision);
        }
      }

      await db.projects.update(scene.projectId, {
        updatedAt: timestamp,
        lastEditedDeviceId: device.id,
        syncStatus: "saved_locally",
        syncError: null
      });
      await db.trashItems.delete(trashItemId);
      await enqueueUpsert("project", scene.projectId);
      restoredItem = {
        ...trashItem,
        payload: {
          scene: {
            ...restoredScene,
            order: insertionIndex
          }
        }
      };
      return;
    }

    const { chapter, scenes } = trashItem.payload as { chapter: ChapterRecord; scenes: SceneRecord[] };
    const chapters = await db.chapters.where("projectId").equals(chapter.projectId).sortBy("order");
    const insertionIndex = Math.max(0, Math.min(trashItem.originalIndex, chapters.length));
    const reorderedChapters = [...chapters];
    const restoredChapter: ChapterRecord = {
      ...chapter,
      order: insertionIndex
    };
    reorderedChapters.splice(insertionIndex, 0, restoredChapter);

    for (const [index, entry] of reorderedChapters.entries()) {
      await db.chapters.put({
        ...entry,
        order: index
      });
      await enqueueUpsert("chapter", entry.id);
    }

    const restoredScenes = [...scenes].sort((left, right) => left.order - right.order);
    for (const scene of restoredScenes) {
      await db.scenes.put(scene);
      if (!scene.syncSuppressed) {
        await enqueueUpsert("scene", scene.id, scene.revision);
      }
    }

    await db.projects.update(chapter.projectId, {
      updatedAt: timestamp,
      lastEditedDeviceId: device.id,
      syncStatus: "saved_locally",
      syncError: null
    });
    await db.trashItems.delete(trashItemId);
    await enqueueUpsert("project", chapter.projectId);
    restoredItem = {
      ...trashItem,
      payload: {
        chapter: restoredChapter,
        scenes: restoredScenes
      }
    };
  });

  return restoredItem;
}

export async function permanentlyDeleteTrashItem(trashItemId: string): Promise<void> {
  const trashItem = await db.trashItems.get(trashItemId);
  if (!trashItem) {
    return;
  }

  const client = getSupabaseClient();
  const {
    data: { session }
  } = client ? await client.auth.getSession() : { data: { session: null } };

    if (client && session?.user && trashItem.ownerUserId === session.user.id) {
      if (trashItem.entityType === "project") {
        const { error } = await client
        .from("novel_projects")
        .delete()
        .eq("id", trashItem.projectId)
        .eq("user_id", session.user.id);

      if (error) {
        throw error;
      }
    } else if (trashItem.entityType === "chapter") {
      const payload = trashItem.payload as { chapter: ChapterRecord };
      const { error } = await client
        .from("novel_chapters")
        .delete()
        .eq("id", payload.chapter.id)
        .eq("user_id", session.user.id);

      if (error) {
        throw error;
      }
    } else if (trashItem.entityType === "scene") {
      const payload = trashItem.payload as { scene: SceneRecord };
      const { error } = await client
        .from("novel_scenes")
        .delete()
        .eq("id", payload.scene.id)
        .eq("user_id", session.user.id);

      if (error) {
        throw error;
      }
      }
    }

  if (trashItem.entityType === "project") {
    const payload = trashItem.payload as { project?: ProjectRecord };
    const trashedProjectFingerprint = payload.project
      ? getProjectFingerprint(payload.project)
      : null;
    const transactionTables = [] as unknown[];
    transactionTables.push(db.projects);
    transactionTables.push(db.chapters);
    transactionTables.push(db.scenes);
    transactionTables.push(db.syncQueue);
    transactionTables.push(db.trashItems);
    transactionTables.push(db.appState);

    await db.transaction("rw", transactionTables as [], async () => {
      if (payload.project) {
        await addDeletedProjectTombstone(payload.project);
      }

      const allProjects = await db.projects.toArray();
      const matchingProjectIds = allProjects
        .filter((project) =>
          project.id === trashItem.projectId ||
          (trashedProjectFingerprint !== null && getProjectFingerprint(project) === trashedProjectFingerprint)
        )
        .map((project) => project.id);

      for (const projectId of matchingProjectIds) {
        await clearQueuedUpsert("project", projectId);

        const chapters = await db.chapters.where("projectId").equals(projectId).toArray();
        const scenes = await db.scenes.where("projectId").equals(projectId).toArray();

        for (const chapter of chapters) {
          await clearQueuedUpsert("chapter", chapter.id);
        }

        for (const scene of scenes) {
          await clearQueuedUpsert("scene", scene.id);
        }

        await db.scenes.where("projectId").equals(projectId).delete();
        await db.chapters.where("projectId").equals(projectId).delete();
        await db.projects.delete(projectId);
      }
      await db.trashItems.delete(trashItemId);
    });
    return;
  }

  await db.trashItems.delete(trashItemId);
}

export async function claimAnonymousProjectsForUser(userId: string): Promise<number> {
  const anonymousProjects = (await db.projects.toArray()).filter((project) => project.ownerUserId === null);
  if (anonymousProjects.length === 0) {
    await db.transaction("rw", db.trashItems, async () => {
      await db.trashItems
        .filter((item) => item.entityType === "project" && item.ownerUserId === null)
        .modify((item) => {
          item.ownerUserId = userId;
        });
    });
    return 0;
  }

  const timestamp = nowIso();
  const anonymousProjectIds = new Set(anonymousProjects.map((project) => project.id));

  const transactionTables = [] as unknown[];
  transactionTables.push(db.projects);
  transactionTables.push(db.chapters);
  transactionTables.push(db.scenes);
  transactionTables.push(db.syncQueue);
  transactionTables.push(db.trashItems);

  await db.transaction("rw", transactionTables as [], async () => {
    for (const project of anonymousProjects) {
      await db.projects.update(project.id, {
        ownerUserId: userId,
        updatedAt: timestamp
      });
      await enqueueUpsert("project", project.id);

      const chapters = await db.chapters.where("projectId").equals(project.id).toArray();
      for (const chapter of chapters) {
        await enqueueUpsert("chapter", chapter.id);
      }

      const scenes = await db.scenes.where("projectId").equals(project.id).toArray();
      for (const scene of scenes) {
        if (!scene.syncSuppressed) {
          await enqueueUpsert("scene", scene.id, scene.revision);
        }
      }
    }

    await db.trashItems
      .filter((item) => item.ownerUserId === null && anonymousProjectIds.has(item.projectId))
      .modify((item) => {
        item.ownerUserId = userId;
      });
  });

  return anonymousProjects.length;
}

export async function reorderChapters(
  projectId: string,
  orderedChapterIds: string[]
): Promise<void> {
  const chapters = await db.chapters.where("projectId").equals(projectId).sortBy("order");
  const chapterMap = new Map(chapters.map((chapter) => [chapter.id, chapter]));
  const orderedChapters = orderedChapterIds
    .map((chapterId) => chapterMap.get(chapterId))
    .filter((chapter): chapter is ChapterRecord => Boolean(chapter));

  if (orderedChapters.length !== chapters.length) {
    return;
  }

  await db.transaction("rw", db.projects, db.chapters, db.syncQueue, async () => {
    for (const [index, chapter] of orderedChapters.entries()) {
      await db.chapters.update(chapter.id, {
        order: index
      });
      await enqueueUpsert("chapter", chapter.id);
    }

    await enqueueUpsert("project", projectId);
  });
}

export async function moveSceneToChapterPosition(
  sceneId: string,
  targetChapterId: string,
  targetOrder: number
): Promise<void> {
  const scene = await db.scenes.get(sceneId);
  if (!scene) {
    return;
  }

  const sourceChapterScenes = await db.scenes.where("chapterId").equals(scene.chapterId).sortBy("order");
  const targetChapterScenes = scene.chapterId === targetChapterId
    ? sourceChapterScenes
    : await db.scenes.where("chapterId").equals(targetChapterId).sortBy("order");

  const nextSourceScenes = sourceChapterScenes.filter((entry) => entry.id !== sceneId);
  const insertionIndex = Math.max(0, Math.min(targetOrder, scene.chapterId === targetChapterId ? nextSourceScenes.length : targetChapterScenes.length));
  const nextTargetScenes = (scene.chapterId === targetChapterId ? nextSourceScenes : targetChapterScenes).slice();
  const movedScene: SceneRecord = {
    ...scene,
    chapterId: targetChapterId
  };
  nextTargetScenes.splice(insertionIndex, 0, movedScene);

  await db.transaction("rw", db.projects, db.scenes, db.syncQueue, async () => {
    for (const [index, entry] of nextSourceScenes.entries()) {
      if (scene.chapterId === targetChapterId && entry.id === sceneId) {
        continue;
      }

      await updateSceneRecord(entry.id, {
        order: index
      });
      if (!entry.syncSuppressed) {
        await enqueueUpsert("scene", entry.id, entry.revision);
      }
    }

    for (const [index, entry] of nextTargetScenes.entries()) {
      await updateSceneRecord(entry.id, {
        chapterId: targetChapterId,
        order: index
      });
      if (!entry.syncSuppressed) {
        await enqueueUpsert("scene", entry.id, entry.revision);
      }
    }

    await enqueueUpsert("project", scene.projectId);
  });
}

export async function listSyncQueueEntries(): Promise<SyncQueueEntry[]> {
  return db.syncQueue.orderBy("updatedAt").toArray();
}

export async function removeSyncQueueEntry(entryId: string): Promise<void> {
  await db.syncQueue.delete(entryId);
}

export async function markSyncQueueEntryAttempt(
  entryId: string,
  error: string | null
): Promise<void> {
  const existing = await db.syncQueue.get(entryId);
  if (!existing) {
    return;
  }

  await db.syncQueue.update(entryId, {
    attemptCount: existing.attemptCount + 1,
    lastAttemptAt: nowIso(),
    lastError: error,
    updatedAt: nowIso()
  });
}

export async function markEntitySyncStatus(
  entityType: EntityType,
  entityId: string,
  status: SyncStatus,
  syncError: string | null
): Promise<void> {
  const timestamp = nowIso();

  if (entityType === "project") {
    await db.projects.update(entityId, {
      syncStatus: status,
      syncError,
      ...(status === "synced"
        ? { lastSyncedAt: timestamp, remoteUpdatedAt: timestamp }
        : {})
    });
    return;
  }

  if (entityType === "chapter") {
    await db.chapters.update(entityId, {
      syncStatus: status,
      syncError,
      ...(status === "synced"
        ? { lastSyncedAt: timestamp, remoteUpdatedAt: timestamp }
        : {})
    });
    return;
  }

  const sceneSyncPatch = status === "synced"
    ? {
        syncStatus: status,
        syncError,
        lastSyncedAt: timestamp,
        remoteUpdatedAt: timestamp
      }
    : {
        syncStatus: status,
        syncError
      };

  await updateSceneRecord(entityId, sceneSyncPatch);
}

export async function markEntitySynced(
  entityType: EntityType,
  entityId: string,
  remoteUpdatedAt: string,
  remoteRevision?: number | null
): Promise<void> {
  const patch = {
    syncStatus: "synced" as const,
    syncError: null,
    lastSyncedAt: nowIso(),
    remoteUpdatedAt
  };

  if (entityType === "project") {
    await db.projects.update(entityId, patch);
    return;
  }

  if (entityType === "chapter") {
    await db.chapters.update(entityId, patch);
    return;
  }

  await updateSceneRecord(entityId, {
    ...patch,
    ...(typeof remoteRevision === "number" ? { remoteRevision } : {})
  });
}

export async function getProjectById(projectId: string): Promise<ProjectRecord | undefined> {
  return db.projects.get(projectId);
}

export async function getChapterById(chapterId: string): Promise<ChapterRecord | undefined> {
  return db.chapters.get(chapterId);
}

export async function getSceneById(sceneId: string): Promise<SceneRecord | undefined> {
  const scene = await db.scenes.get(sceneId);
  if (!scene) {
    return undefined;
  }

  const contentJson = sanitizeRichTextContent(normalizeRichTextContent(scene));
  const metrics = getTextMetrics(contentJson);
  return {
    ...scene,
    contentJson,
    contentText: scene.contentText ?? metrics.plainText,
    wordCount: scene.wordCount ?? metrics.wordCount,
    characterCount: scene.characterCount ?? metrics.characterCount,
    revision: scene.revision ?? 1,
    remoteRevision: scene.remoteRevision ?? null
  };
}

export async function getSceneEditorSession(sceneId: string): Promise<SceneEditorSession | null> {
  const record = await db.appState.get(getSceneEditorSessionKey(sceneId));
  return (record?.value as SceneEditorSession | undefined) ?? null;
}

export async function saveSceneEditorSession(session: SceneEditorSession): Promise<void> {
  await db.appState.put({
    key: getSceneEditorSessionKey(session.sceneId),
    value: session
  });
}

export async function persistWorkspaceSession(
  updater: (current: WorkspaceSession) => WorkspaceSession
): Promise<WorkspaceSession> {
  const current = await getWorkspaceSession();
  const next = updater(current);
  await saveWorkspaceSession(next);
  return next;
}

export async function getAllLocalEntities(): Promise<{
  projects: ProjectRecord[];
  chapters: ChapterRecord[];
  scenes: SceneRecord[];
}> {
  const [projects, chapters, scenes] = await Promise.all([
    db.projects.toArray(),
    db.chapters.toArray(),
    db.scenes.toArray()
  ]);

  return { projects, chapters, scenes: sortScenes(scenes) };
}

export async function getOwnedLocalEntities(userId: string): Promise<{
  projects: ProjectRecord[];
  chapters: ChapterRecord[];
  scenes: SceneRecord[];
}> {
  const projects = await db.projects.where("ownerUserId").equals(userId).toArray();
  const projectIds = new Set(projects.map((project) => project.id));
  const [chapters, scenes] = await Promise.all([
    db.chapters.toArray(),
    db.scenes.toArray()
  ]);

  return {
    projects,
    chapters: chapters.filter((chapter) => projectIds.has(chapter.projectId)),
    scenes: sortScenes(scenes.filter((scene) => projectIds.has(scene.projectId)))
  };
}

export async function upsertRemoteProjectLocally(
  row: RemoteProjectRow,
  status: SyncStatus = "synced"
): Promise<void> {
  const existing = await db.projects.get(row.id);
  const local: ProjectRecord = {
    id: row.id,
    ownerUserId: row.user_id,
    title: row.title,
    createdAt: existing?.createdAt ?? row.created_at,
    updatedAt: row.updated_at,
    lastEditedDeviceId: row.last_edited_device_id,
    lastSyncedAt: nowIso(),
    remoteUpdatedAt: row.updated_at,
    syncError: null,
    syncStatus: status
  };

  await db.projects.put(local);
}

export async function upsertRemoteChapterLocally(
  row: RemoteChapterRow,
  status: SyncStatus = "synced"
): Promise<void> {
  const existing = await db.chapters.get(row.id);
  const local: ChapterRecord = {
    id: row.id,
    projectId: row.project_id,
    title: row.title,
    order: row.order_index,
    createdAt: existing?.createdAt ?? row.created_at,
    updatedAt: row.updated_at,
    lastEditedDeviceId: row.last_edited_device_id,
    lastSyncedAt: nowIso(),
    remoteUpdatedAt: row.updated_at,
    syncError: null,
    syncStatus: status
  };

  await db.chapters.put(local);
}

export async function upsertRemoteSceneLocally(
  row: RemoteSceneRow,
  status: SyncStatus = "synced"
): Promise<void> {
  const existing = await db.scenes.get(row.id);
  const contentJson = sanitizeRichTextContent(row.content_json);
  const metrics = getTextMetrics(contentJson);

  const local: SceneRecord = {
    id: row.id,
    projectId: row.project_id,
    chapterId: row.chapter_id,
    title: row.title,
    contentJson,
    contentText: metrics.plainText,
    wordCount: metrics.wordCount,
    characterCount: metrics.characterCount,
    order: row.order_index,
    revision: row.revision,
    createdAt: existing?.createdAt ?? row.created_at,
    updatedAt: row.updated_at,
    lastEditedDeviceId: row.last_edited_device_id,
    lastSyncedAt: nowIso(),
    remoteUpdatedAt: row.updated_at,
    remoteRevision: row.revision,
    syncError: null,
    syncStatus: status,
    conflictState: existing?.conflictState ?? "none",
    conflictGroupId: existing?.conflictGroupId ?? null,
    remoteOriginalId: existing?.remoteOriginalId ?? null,
    syncSuppressed: existing?.syncSuppressed ?? false
  };

  await db.scenes.put(local);
}

export async function createRemoteConflictCopy(
  remoteScene: RemoteSceneRow,
  deviceId: string,
  conflictGroupId: string
): Promise<SceneRecord> {
  const contentJson = sanitizeRichTextContent(remoteScene.content_json);
  const metrics = getTextMetrics(contentJson);
  const timestamp = nowIso();
  const copy: SceneRecord = {
    id: createId("scene"),
    projectId: remoteScene.project_id,
    chapterId: remoteScene.chapter_id,
    title: `${remoteScene.title} (Remote conflict copy)`,
    contentJson,
    contentText: metrics.plainText,
    wordCount: metrics.wordCount,
    characterCount: metrics.characterCount,
    order: remoteScene.order_index,
    revision: remoteScene.revision,
    createdAt: timestamp,
    updatedAt: remoteScene.updated_at,
    lastEditedDeviceId: remoteScene.last_edited_device_id ?? deviceId,
    lastSyncedAt: nowIso(),
    remoteUpdatedAt: remoteScene.updated_at,
    remoteRevision: remoteScene.revision,
    syncError: null,
    syncStatus: "conflict",
    conflictState: "remote_copy",
    conflictGroupId,
    remoteOriginalId: remoteScene.id,
    syncSuppressed: true
  };

  await db.scenes.add(copy);
  return copy;
}

export async function markSceneConflict(
  sceneId: string,
  conflictGroupId: string,
  syncError: string | null = null
): Promise<void> {
  await updateSceneRecord(sceneId, {
    conflictState: "local",
    conflictGroupId,
    syncStatus: "conflict",
    syncError
  });
}

export async function listSceneConflicts(): Promise<SceneRecord[]> {
  return db.scenes.where("conflictState").notEqual("none").toArray();
}

export async function getSceneByRemoteOriginalId(remoteOriginalId: string): Promise<SceneRecord | undefined> {
  return db.scenes.toCollection().filter((scene) => scene.remoteOriginalId === remoteOriginalId).first();
}

function getSceneEditorSessionKey(sceneId: string): string {
  return `scene-editor-session:${sceneId}`;
}

export async function getSyncQueueSize(): Promise<number> {
  return db.syncQueue.count();
}

export async function clearEntitySyncError(entityType: EntityType, entityId: string): Promise<void> {
  if (entityType === "project") {
    await db.projects.update(entityId, { syncError: null });
    return;
  }

  if (entityType === "chapter") {
    await db.chapters.update(entityId, { syncError: null });
    return;
  }

  await updateSceneRecord(entityId, { syncError: null });
}

export async function getWorkspaceSessionSnapshot(): Promise<WorkspaceSession> {
  return getWorkspaceSession();
}

export async function setEntitySyncing(entityType: EntityType, entityId: string): Promise<void> {
  await markEntitySyncStatus(entityType, entityId, "syncing", null);
}

export async function updateSceneConflictState(
  sceneId: string,
  conflictState: ConflictState,
  conflictGroupId: string | null,
  syncStatus: SyncStatus
): Promise<void> {
  await updateSceneRecord(sceneId, {
    conflictState,
    conflictGroupId,
    syncStatus
  });
}
