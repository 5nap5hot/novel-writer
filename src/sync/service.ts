import { createId } from "../lib/id";
import { getSupabaseClient } from "../lib/supabase";
import {
  clearEntitySyncError,
  createRemoteConflictCopy,
  getDeletedProjectTombstonesSnapshot,
  ensureDeviceIdentity,
  getChapterById,
  getOwnedLocalEntities,
  getProjectById,
  getSceneById,
  getSceneByRemoteOriginalId,
  listProjectTrashItems,
  listSyncQueueEntries,
  markEntitySynced,
  markEntitySyncStatus,
  markSceneConflict,
  removeSyncQueueEntry,
  setEntitySyncing,
  upsertRemoteChapterLocally,
  upsertRemoteProjectLocally,
  upsertRemoteSceneLocally,
  markSyncQueueEntryAttempt
} from "../db/repositories";
import type {
  EntityType,
  RemoteChapterRow,
  RemoteProjectRow,
  RemoteSceneRow,
  SceneRecord,
  SyncQueueEntry,
  SyncRunSummary
} from "../types/models";

const REMOTE_PROJECTS_TABLE = "novel_projects";
const REMOTE_CHAPTERS_TABLE = "novel_chapters";
const REMOTE_SCENES_TABLE = "novel_scenes";

function getRemoteProjectFingerprint(project: Pick<RemoteProjectRow, "title" | "created_at">): string {
  return `${project.title}::${project.created_at}`;
}

export async function runSyncCycle(): Promise<SyncRunSummary> {
  const client = getSupabaseClient();
  if (!client) {
    return { pushed: 0, pulled: 0, conflicts: 0, failed: 0 };
  }

  const {
    data: { session }
  } = await client.auth.getSession();

  if (!session?.user) {
    return { pushed: 0, pulled: 0, conflicts: 0, failed: 0 };
  }

  const device = await ensureDeviceIdentity();
  const summary: SyncRunSummary = { pushed: 0, pulled: 0, conflicts: 0, failed: 0 };
  const queue = await listSyncQueueEntries();
  const pendingMap = new Map(queue.map((entry) => [`${entry.entityType}:${entry.entityId}`, entry]));

  for (const entry of queue) {
    const result = await pushQueueEntry(entry, session.user.id, device.id);
    summary.pushed += result.pushed;
    summary.conflicts += result.conflicts;
    summary.failed += result.failed;
    if (result.handled) {
      pendingMap.delete(`${entry.entityType}:${entry.entityId}`);
    }
  }

  const pullSummary = await pullRemoteChanges(session.user.id, device.id, pendingMap);
  summary.pulled += pullSummary.pulled;
  summary.conflicts += pullSummary.conflicts;
  summary.failed += pullSummary.failed;

  return summary;
}

async function pushQueueEntry(
  entry: SyncQueueEntry,
  userId: string,
  deviceId: string
): Promise<{ pushed: number; conflicts: number; failed: number; handled: boolean }> {
  const client = getSupabaseClient();
  if (!client) {
    return { pushed: 0, conflicts: 0, failed: 0, handled: false };
  }

  try {
    if (entry.entityType === "project") {
      await setEntitySyncing(entry.entityType, entry.entityId);
      await clearEntitySyncError(entry.entityType, entry.entityId);
      const local = await getProjectById(entry.entityId);
      if (!local) {
        await removeSyncQueueEntry(entry.id);
        return { pushed: 0, conflicts: 0, failed: 0, handled: true };
      }

      const row: RemoteProjectRow = {
        id: local.id,
        user_id: userId,
        title: local.title,
        created_at: local.createdAt,
        updated_at: local.updatedAt,
        last_edited_device_id: local.lastEditedDeviceId
      };
      const { data, error } = await client
        .from(REMOTE_PROJECTS_TABLE)
        .upsert(row, { onConflict: "id" })
        .select("updated_at")
        .single();

      if (error) {
        throw error;
      }

      await markEntitySynced("project", local.id, (data?.updated_at as string | undefined) ?? local.updatedAt);
      await removeSyncQueueEntry(entry.id);
      return { pushed: 1, conflicts: 0, failed: 0, handled: true };
    }

    if (entry.entityType === "chapter") {
      await setEntitySyncing(entry.entityType, entry.entityId);
      await clearEntitySyncError(entry.entityType, entry.entityId);
      const local = await getChapterById(entry.entityId);
      if (!local) {
        await removeSyncQueueEntry(entry.id);
        return { pushed: 0, conflicts: 0, failed: 0, handled: true };
      }

      const row: RemoteChapterRow = {
        id: local.id,
        user_id: userId,
        project_id: local.projectId,
        title: local.title,
        order_index: local.order,
        created_at: local.createdAt,
        updated_at: local.updatedAt,
        last_edited_device_id: local.lastEditedDeviceId
      };
      const { data, error } = await client
        .from(REMOTE_CHAPTERS_TABLE)
        .upsert(row, { onConflict: "id" })
        .select("updated_at")
        .single();

      if (error) {
        throw error;
      }

      await markEntitySynced("chapter", local.id, (data?.updated_at as string | undefined) ?? local.updatedAt);
      await removeSyncQueueEntry(entry.id);
      return { pushed: 1, conflicts: 0, failed: 0, handled: true };
    }

    const localScene = await getSceneById(entry.entityId);
    if (!localScene) {
      await removeSyncQueueEntry(entry.id);
      return { pushed: 0, conflicts: 0, failed: 0, handled: true };
    }

    if (localScene.syncSuppressed) {
      await removeSyncQueueEntry(entry.id);
      return { pushed: 0, conflicts: 0, failed: 0, handled: true };
    }

    if (entry.entityRevision !== null && entry.entityRevision < localScene.revision) {
      await removeSyncQueueEntry(entry.id);
      return { pushed: 0, conflicts: 0, failed: 0, handled: true };
    }

    if (entry.entityRevision !== null && entry.entityRevision > localScene.revision) {
      await removeSyncQueueEntry(entry.id);
      return { pushed: 0, conflicts: 0, failed: 0, handled: true };
    }

    await setEntitySyncing(entry.entityType, entry.entityId);
    await clearEntitySyncError(entry.entityType, entry.entityId);

    const { data: remoteScene, error: fetchError } = await client
      .from(REMOTE_SCENES_TABLE)
      .select("*")
      .eq("id", localScene.id)
      .maybeSingle();

    if (fetchError) {
      throw fetchError;
    }

    if (shouldCreateConflict(localScene, remoteScene as RemoteSceneRow | null)) {
      const conflictGroupId = createId("conflict");
      await markSceneConflict(localScene.id, conflictGroupId, "Remote scene changed since last successful sync.");

      const existingCopy = await getSceneByRemoteOriginalId(localScene.id);
      if (!existingCopy && remoteScene) {
        await createRemoteConflictCopy(remoteScene as RemoteSceneRow, deviceId, conflictGroupId);
      }

      await removeSyncQueueEntry(entry.id);
      return { pushed: 0, conflicts: 1, failed: 0, handled: true };
    }

    const row: RemoteSceneRow = {
      id: localScene.id,
      user_id: userId,
      project_id: localScene.projectId,
      chapter_id: localScene.chapterId,
      title: localScene.title,
      content_json: localScene.contentJson,
      content_text: localScene.contentText,
      word_count: localScene.wordCount,
      character_count: localScene.characterCount,
      order_index: localScene.order,
      revision: localScene.revision,
      created_at: localScene.createdAt,
      updated_at: localScene.updatedAt,
      last_edited_device_id: localScene.lastEditedDeviceId
    };
    const { data, error } = await client
      .from(REMOTE_SCENES_TABLE)
      .upsert(row, { onConflict: "id" })
      .select("updated_at")
      .single();

    if (error) {
      throw error;
    }

    await markEntitySynced(
      "scene",
      localScene.id,
      (data?.updated_at as string | undefined) ?? localScene.updatedAt,
      localScene.revision
    );
    await removeSyncQueueEntry(entry.id);
    return { pushed: 1, conflicts: 0, failed: 0, handled: true };
  } catch (error) {
    const message = error instanceof Error ? error.message : "Sync push failed";
    await markSyncQueueEntryAttempt(entry.id, message);
    await markEntitySyncStatus(entry.entityType, entry.entityId, "sync_failed", message);
    return { pushed: 0, conflicts: 0, failed: 1, handled: false };
  }
}

async function pullRemoteChanges(
  userId: string,
  deviceId: string,
  pendingMap: Map<string, SyncQueueEntry>
): Promise<{ pulled: number; conflicts: number; failed: number }> {
  const client = getSupabaseClient();
  if (!client) {
    return { pulled: 0, conflicts: 0, failed: 0 };
  }

  try {
    const [{ data: remoteProjects, error: projectError }, { data: remoteChapters, error: chapterError }, { data: remoteScenes, error: sceneError }] =
      await Promise.all([
        client.from(REMOTE_PROJECTS_TABLE).select("*").eq("user_id", userId),
        client.from(REMOTE_CHAPTERS_TABLE).select("*").eq("user_id", userId),
        client.from(REMOTE_SCENES_TABLE).select("*").eq("user_id", userId)
      ]);

    if (projectError) {
      throw projectError;
    }
    if (chapterError) {
      throw chapterError;
    }
    if (sceneError) {
      throw sceneError;
    }

    const local = await getOwnedLocalEntities(userId);
    const trashedProjectItems = await listProjectTrashItems({ ownerUserId: userId, includeAnonymous: true });
    const trashedProjectIds = new Set(trashedProjectItems.map((item) => item.projectId));
    const trashedFingerprints = new Set(
      trashedProjectItems
        .map((item) => {
          const payload = item.payload as { project?: { title: string; createdAt: string } };
          return payload.project ? `${payload.project.title}::${payload.project.createdAt}` : null;
        })
        .filter((value): value is string => Boolean(value))
    );
    const tombstones = await getDeletedProjectTombstonesSnapshot();
    const tombstonedProjectIds = new Set(tombstones.ids);
    const tombstonedFingerprints = new Set(tombstones.fingerprints);
    const skippedRemoteProjectIds = new Set<string>();
    let pulled = 0;
    let conflicts = 0;

    for (const remoteProject of (remoteProjects ?? []) as RemoteProjectRow[]) {
      if (
        trashedProjectIds.has(remoteProject.id) ||
        trashedFingerprints.has(getRemoteProjectFingerprint(remoteProject)) ||
        tombstonedProjectIds.has(remoteProject.id) ||
        tombstonedFingerprints.has(getRemoteProjectFingerprint(remoteProject))
      ) {
        skippedRemoteProjectIds.add(remoteProject.id);
        continue;
      }

      const localProject = local.projects.find((project) => project.id === remoteProject.id);
      if (!localProject || shouldApplyRemote(localProject, remoteProject.updated_at, pendingMap.has(`project:${remoteProject.id}`))) {
        await upsertRemoteProjectLocally(remoteProject);
        pulled += 1;
      }
    }

    for (const remoteChapter of (remoteChapters ?? []) as RemoteChapterRow[]) {
      if (trashedProjectIds.has(remoteChapter.project_id) || skippedRemoteProjectIds.has(remoteChapter.project_id)) {
        continue;
      }

      const localChapter = local.chapters.find((chapter) => chapter.id === remoteChapter.id);
      if (!localChapter || shouldApplyRemote(localChapter, remoteChapter.updated_at, pendingMap.has(`chapter:${remoteChapter.id}`))) {
        await upsertRemoteChapterLocally(remoteChapter);
        pulled += 1;
      }
    }

    for (const remoteScene of (remoteScenes ?? []) as RemoteSceneRow[]) {
      if (trashedProjectIds.has(remoteScene.project_id) || skippedRemoteProjectIds.has(remoteScene.project_id)) {
        continue;
      }

      const localScene = local.scenes.find((scene) => scene.id === remoteScene.id);
      const hasPendingLocal = pendingMap.has(`scene:${remoteScene.id}`);

      if (!localScene) {
        await upsertRemoteSceneLocally(remoteScene);
        pulled += 1;
        continue;
      }

      if (shouldCreateConflict(localScene, remoteScene)) {
        const conflictGroupId = createId("conflict");
        await markSceneConflict(localScene.id, conflictGroupId, "Remote scene changed since last successful sync.");
        const existingCopy = await getSceneByRemoteOriginalId(remoteScene.id);
        if (!existingCopy) {
          await createRemoteConflictCopy(remoteScene, deviceId, conflictGroupId);
        }
        conflicts += 1;
        continue;
      }

      if (shouldApplyRemoteScene(localScene, remoteScene.revision, hasPendingLocal)) {
        await upsertRemoteSceneLocally(remoteScene);
        pulled += 1;
      }
    }

    return { pulled, conflicts, failed: 0 };
  } catch (error) {
    console.error("Novel Writer sync pull failed", error);
    return { pulled: 0, conflicts: 0, failed: 1 };
  }
}

function shouldApplyRemote(
  localEntity: { remoteUpdatedAt: string | null; lastSyncedAt: string | null },
  remoteUpdatedAt: string,
  hasPendingLocal: boolean
): boolean {
  if (hasPendingLocal) {
    return false;
  }

  const baseline = localEntity.remoteUpdatedAt ?? localEntity.lastSyncedAt;
  if (!baseline) {
    return true;
  }

  return remoteUpdatedAt > baseline;
}

function shouldApplyRemoteScene(
  localScene: Pick<SceneRecord, "remoteRevision">,
  remoteRevision: number,
  hasPendingLocal: boolean
): boolean {
  if (hasPendingLocal) {
    return false;
  }

  const baselineRevision = localScene.remoteRevision;
  if (baselineRevision === null) {
    return true;
  }

  return remoteRevision > baselineRevision;
}

function shouldCreateConflict(
  localScene: Pick<SceneRecord, "revision" | "remoteRevision" | "syncSuppressed">,
  remoteScene: RemoteSceneRow | null
): boolean {
  if (!remoteScene || localScene.syncSuppressed) {
    return false;
  }

  const baselineRevision = localScene.remoteRevision;
  if (baselineRevision === null) {
    return false;
  }

  const localChangedSinceSync = localScene.revision > baselineRevision;
  const remoteChangedSinceSync = remoteScene.revision > baselineRevision;
  return localChangedSinceSync && remoteChangedSinceSync;
}
