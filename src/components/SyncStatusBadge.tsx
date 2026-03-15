import type { SyncStatus } from "../types/models";

interface SyncStatusBadgeProps {
  status: SyncStatus;
  pendingCount: number;
  conflictCount?: number;
  onManualSync?: () => void;
}

const LABELS: Record<SyncStatus, string> = {
  saved_locally: "Saved locally",
  syncing: "Syncing",
  synced: "Synced",
  offline: "Offline",
  conflict: "Conflict",
  sync_failed: "Sync failed"
};

export function SyncStatusBadge({
  status,
  pendingCount,
  conflictCount = 0,
  onManualSync
}: SyncStatusBadgeProps) {
  const isSyncing = status === "syncing";

  return (
    <div className={`sync-status-badge is-${status}`}>
      <span className="sync-status-main">
        {isSyncing ? (
          <span className="sync-status-spinner" aria-hidden="true" />
        ) : (
          <span className="sync-status-dot" aria-hidden="true" />
        )}
        <span>{LABELS[status]}</span>
        {isSyncing ? (
          <span className="sync-status-ellipsis" aria-hidden="true">
            <span>.</span>
            <span>.</span>
            <span>.</span>
          </span>
        ) : null}
      </span>
      {pendingCount > 0 ? <span>{pendingCount} queued</span> : null}
      {conflictCount > 0 ? <span>{conflictCount} conflict{conflictCount === 1 ? "" : "s"}</span> : null}
      {onManualSync ? (
        <button
          className="sync-icon-button"
          type="button"
          onClick={onManualSync}
          disabled={isSyncing}
          aria-label="Sync now"
          title="Sync now"
        >
          <SyncArrowsIcon />
        </button>
      ) : null}
    </div>
  );
}

function SyncArrowsIcon() {
  return (
    <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M4 7.25A6.25 6.25 0 0 1 14.65 4.4" />
      <path d="M14.5 2.75v2.9h-2.9" />
      <path d="M16 12.75A6.25 6.25 0 0 1 5.35 15.6" />
      <path d="M5.5 17.25v-2.9h2.9" />
    </svg>
  );
}
