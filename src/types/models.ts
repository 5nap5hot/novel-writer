export type AuthMode = "local" | "supabase";
export type SyncStatus =
  | "saved_locally"
  | "syncing"
  | "synced"
  | "offline"
  | "conflict"
  | "sync_failed";
export type EntityType = "project" | "chapter" | "scene";
export type ConflictState = "none" | "local" | "remote_copy";
export type TrashEntityType = "project" | "chapter" | "scene";

export interface RichTextContent {
  type?: string;
  text?: string;
  attrs?: Record<string, unknown>;
  marks?: RichTextContent[];
  content?: RichTextContent[];
}

export interface SyncMetadata {
  lastEditedDeviceId: string | null;
  lastSyncedAt: string | null;
  remoteUpdatedAt: string | null;
  syncError: string | null;
  syncStatus: SyncStatus;
}

export interface ProjectRecord {
  id: string;
  ownerUserId: string | null;
  title: string;
  createdAt: string;
  updatedAt: string;
  lastEditedDeviceId: string | null;
  lastSyncedAt: string | null;
  remoteUpdatedAt: string | null;
  syncError: string | null;
  syncStatus: SyncStatus;
}

export interface ChapterRecord {
  id: string;
  projectId: string;
  title: string;
  order: number;
  createdAt: string;
  updatedAt: string;
  lastEditedDeviceId: string | null;
  lastSyncedAt: string | null;
  remoteUpdatedAt: string | null;
  syncError: string | null;
  syncStatus: SyncStatus;
}

export interface SceneRecord {
  id: string;
  projectId: string;
  chapterId: string;
  title: string;
  contentJson: RichTextContent;
  contentText: string;
  wordCount: number;
  characterCount: number;
  content?: string;
  order: number;
  revision: number;
  createdAt: string;
  updatedAt: string;
  lastEditedDeviceId: string | null;
  lastSyncedAt: string | null;
  remoteUpdatedAt: string | null;
  remoteRevision: number | null;
  syncError: string | null;
  syncStatus: SyncStatus;
  conflictState: ConflictState;
  conflictGroupId: string | null;
  remoteOriginalId: string | null;
  syncSuppressed: boolean;
}

export interface AppStateRecord<T = unknown> {
  key: string;
  value: T;
}

export interface WorkspaceSession {
  authMode: AuthMode;
  lastProjectId: string | null;
  lastChapterId: string | null;
  lastSceneId: string | null;
  expandedChapterIdsByProject: Record<string, string[]>;
  editorZoomPercent: number;
}

export interface DeviceIdentity {
  id: string;
  label: string;
  createdAt: string;
}

export interface AuthenticatedUser {
  id: string;
  email: string | null;
}

export interface SceneEditorSession {
  sceneId: string;
  cursorFrom: number | null;
  cursorTo: number | null;
  scrollTop: number;
  updatedAt: string;
}

export interface SupabaseCredentials {
  email: string;
  password: string;
}

export interface SyncQueueEntry {
  id: string;
  dedupeKey: string;
  entityType: EntityType;
  entityId: string;
  entityRevision: number | null;
  operation: "upsert";
  createdAt: string;
  updatedAt: string;
  attemptCount: number;
  lastAttemptAt: string | null;
  lastError: string | null;
}

export interface TrashedScenePayload {
  scene: SceneRecord;
}

export interface TrashedChapterPayload {
  chapter: ChapterRecord;
  scenes: SceneRecord[];
}

export interface TrashedProjectPayload {
  project: ProjectRecord;
  chapters: ChapterRecord[];
  scenes: SceneRecord[];
}

export interface TrashItemRecord {
  id: string;
  projectId: string;
  ownerUserId: string | null;
  entityType: TrashEntityType;
  title: string;
  deletedAt: string;
  originalParentId: string | null;
  originalParentTitle: string | null;
  originalIndex: number;
  payload: TrashedScenePayload | TrashedChapterPayload | TrashedProjectPayload;
}

export interface RemoteProjectRow {
  id: string;
  user_id: string;
  title: string;
  created_at: string;
  updated_at: string;
  last_edited_device_id: string | null;
}

export interface RemoteChapterRow {
  id: string;
  user_id: string;
  project_id: string;
  title: string;
  order_index: number;
  created_at: string;
  updated_at: string;
  last_edited_device_id: string | null;
}

export interface RemoteSceneRow {
  id: string;
  user_id: string;
  project_id: string;
  chapter_id: string;
  title: string;
  content_json: RichTextContent;
  content_text: string;
  word_count: number;
  character_count: number;
  order_index: number;
  revision: number;
  created_at: string;
  updated_at: string;
  last_edited_device_id: string | null;
}

export interface SyncRunSummary {
  pushed: number;
  pulled: number;
  conflicts: number;
  failed: number;
}
