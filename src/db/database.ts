import Dexie, { type Table } from "dexie";

import type {
  AppStateRecord,
  ChapterRecord,
  ProjectRecord,
  SceneRecord,
  SyncQueueEntry,
  TrashItemRecord
} from "../types/models";
import {
  EMPTY_DOCUMENT,
  getTextMetrics,
  normalizeRichTextContent,
  sanitizeRichTextContent
} from "../lib/editorContent";

export class NovelWriterDatabase extends Dexie {
  projects!: Table<ProjectRecord, string>;
  chapters!: Table<ChapterRecord, string>;
  scenes!: Table<SceneRecord, string>;
  appState!: Table<AppStateRecord, string>;
  syncQueue!: Table<SyncQueueEntry, string>;
  trashItems!: Table<TrashItemRecord, string>;

  constructor() {
    super("novel-writer");

    this.version(1).stores({
      projects: "id, updatedAt",
      chapters: "id, projectId, [projectId+order], updatedAt",
      scenes: "id, projectId, chapterId, [chapterId+order], updatedAt",
      appState: "key"
    });

    this.version(2)
      .stores({
        projects: "id, updatedAt",
        chapters: "id, projectId, [projectId+order], updatedAt",
        scenes: "id, projectId, chapterId, [chapterId+order], updatedAt",
        appState: "key"
      })
      .upgrade(async (transaction) => {
        const scenesTable = transaction.table<SceneRecord, string>("scenes");
        await scenesTable.toCollection().modify((scene) => {
          const contentJson = normalizeRichTextContent(scene);
          const metrics = getTextMetrics(contentJson);

          scene.contentJson = contentJson ?? EMPTY_DOCUMENT;
          scene.contentText = metrics.plainText;
          scene.wordCount = metrics.wordCount;
          scene.characterCount = metrics.characterCount;
        });
      });

    this.version(3)
      .stores({
        projects: "id, updatedAt",
        chapters: "id, projectId, [projectId+order], updatedAt",
        scenes: "id, projectId, chapterId, [chapterId+order], updatedAt",
        appState: "key"
      })
      .upgrade(async (transaction) => {
        const scenesTable = transaction.table<SceneRecord, string>("scenes");
        await scenesTable.toCollection().modify((scene) => {
          const contentJson = sanitizeRichTextContent(normalizeRichTextContent(scene));
          const metrics = getTextMetrics(contentJson);

          scene.contentJson = contentJson;
          scene.contentText = metrics.plainText;
          scene.wordCount = metrics.wordCount;
          scene.characterCount = metrics.characterCount;
        });
      });

    this.version(4)
      .stores({
        projects: "id, updatedAt",
        chapters: "id, projectId, [projectId+order], updatedAt",
        scenes: "id, projectId, chapterId, [chapterId+order], updatedAt, syncStatus, conflictState",
        appState: "key",
        syncQueue: "id, dedupeKey, entityType, entityId, updatedAt"
      })
      .upgrade(async (transaction) => {
        const projectsTable = transaction.table<ProjectRecord, string>("projects");
        const chaptersTable = transaction.table<ChapterRecord, string>("chapters");
        const scenesTable = transaction.table<SceneRecord, string>("scenes");

        await projectsTable.toCollection().modify((project) => {
          project.lastEditedDeviceId = project.lastEditedDeviceId ?? null;
          project.lastSyncedAt = project.lastSyncedAt ?? null;
          project.remoteUpdatedAt = project.remoteUpdatedAt ?? null;
          project.syncError = project.syncError ?? null;
          project.syncStatus = project.syncStatus ?? "saved_locally";
        });

        await chaptersTable.toCollection().modify((chapter) => {
          chapter.lastEditedDeviceId = chapter.lastEditedDeviceId ?? null;
          chapter.lastSyncedAt = chapter.lastSyncedAt ?? null;
          chapter.remoteUpdatedAt = chapter.remoteUpdatedAt ?? null;
          chapter.syncError = chapter.syncError ?? null;
          chapter.syncStatus = chapter.syncStatus ?? "saved_locally";
        });

        await scenesTable.toCollection().modify((scene) => {
          scene.lastEditedDeviceId = scene.lastEditedDeviceId ?? null;
          scene.lastSyncedAt = scene.lastSyncedAt ?? null;
          scene.remoteUpdatedAt = scene.remoteUpdatedAt ?? null;
          scene.syncError = scene.syncError ?? null;
          scene.syncStatus = scene.syncStatus ?? "saved_locally";
          scene.conflictState = scene.conflictState ?? "none";
          scene.conflictGroupId = scene.conflictGroupId ?? null;
          scene.remoteOriginalId = scene.remoteOriginalId ?? null;
          scene.syncSuppressed = scene.syncSuppressed ?? false;
        });
      });

    this.version(5)
      .stores({
        projects: "id, updatedAt",
        chapters: "id, projectId, [projectId+order], updatedAt",
        scenes: "id, projectId, chapterId, [chapterId+order], updatedAt, syncStatus, conflictState, revision",
        appState: "key",
        syncQueue: "id, dedupeKey, entityType, entityId, entityRevision, updatedAt"
      })
      .upgrade(async (transaction) => {
        const scenesTable = transaction.table<SceneRecord, string>("scenes");
        const syncQueueTable = transaction.table<SyncQueueEntry, string>("syncQueue");

        await scenesTable.toCollection().modify((scene) => {
          scene.revision = scene.revision ?? 1;
          scene.remoteRevision = scene.remoteRevision ?? null;
        });

        await syncQueueTable.toCollection().modify((entry) => {
          entry.entityRevision = entry.entityRevision ?? null;
        });
      });

    this.version(6)
      .stores({
        projects: "id, updatedAt",
        chapters: "id, projectId, [projectId+order], updatedAt",
        scenes: "id, projectId, chapterId, [chapterId+order], updatedAt, syncStatus, conflictState, revision",
        appState: "key",
        syncQueue: "id, dedupeKey, entityType, entityId, entityRevision, updatedAt",
        trashItems: "id, projectId, entityType, deletedAt"
      })
      .upgrade(async (transaction) => {
        const trashItemsTable = transaction.table<TrashItemRecord, string>("trashItems");
        await trashItemsTable.toCollection().modify((trashItem) => {
          trashItem.originalParentTitle = trashItem.originalParentTitle ?? null;
        });
      });

    this.version(7)
      .stores({
        projects: "id, ownerUserId, updatedAt",
        chapters: "id, projectId, [projectId+order], updatedAt",
        scenes: "id, projectId, chapterId, [chapterId+order], updatedAt, syncStatus, conflictState, revision",
        appState: "key",
        syncQueue: "id, dedupeKey, entityType, entityId, entityRevision, updatedAt",
        trashItems: "id, projectId, entityType, deletedAt"
      })
      .upgrade(async (transaction) => {
        const projectsTable = transaction.table<ProjectRecord, string>("projects");
        await projectsTable.toCollection().modify((project) => {
          project.ownerUserId = project.ownerUserId ?? null;
        });
      });

    this.version(8)
      .stores({
        projects: "id, ownerUserId, updatedAt",
        chapters: "id, projectId, [projectId+order], updatedAt",
        scenes: "id, projectId, chapterId, [chapterId+order], updatedAt, syncStatus, conflictState, revision",
        appState: "key",
        syncQueue: "id, dedupeKey, entityType, entityId, entityRevision, updatedAt",
        trashItems: "id, projectId, ownerUserId, entityType, deletedAt"
      })
      .upgrade(async (transaction) => {
        const trashItemsTable = transaction.table<TrashItemRecord, string>("trashItems");
        await trashItemsTable.toCollection().modify((trashItem) => {
          trashItem.ownerUserId = trashItem.ownerUserId ?? null;
        });
      });
  }
}

export const db = new NovelWriterDatabase();
