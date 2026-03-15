import { db } from "./database";
import type { WorkspaceSession } from "../types/models";

const SESSION_KEY = "workspace-session";

export const defaultWorkspaceSession: WorkspaceSession = {
  authMode: "local",
  lastProjectId: null,
  lastChapterId: null,
  lastSceneId: null,
  expandedChapterIdsByProject: {},
  editorZoomPercent: 100
};

export async function getWorkspaceSession(): Promise<WorkspaceSession> {
  const record = await db.appState.get(SESSION_KEY);
  return {
    ...defaultWorkspaceSession,
    ...(record?.value as Partial<WorkspaceSession> | undefined)
  };
}

export async function saveWorkspaceSession(
  session: WorkspaceSession
): Promise<void> {
  await db.appState.put({
    key: SESSION_KEY,
    value: session
  });
}
