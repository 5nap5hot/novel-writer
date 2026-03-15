# SYNC_DESIGN

## Local Sync Queue Structure

Novel Writer uses a durable local sync queue stored in IndexedDB in the `syncQueue` table.

Each queue entry contains:

- `id`
- `dedupeKey`
- `entityType`
  - `project`
  - `chapter`
  - `scene`
- `entityId`
- `entityRevision`
  - scene revision captured when the queue entry was last written
  - `null` for entities that do not currently use revision-based sync
- `operation`
  - currently `upsert` only
- `createdAt`
- `updatedAt`
- `attemptCount`
- `lastAttemptAt`
- `lastError`

Queue behavior:

- local create and update operations enqueue work immediately
- entries are deduplicated by `dedupeKey`
- the current implementation uses `entityType:entityId:upsert` as the dedupe key
- queue entries persist across app restarts
- sync pushes queued local changes before pulling remote changes
- stale scene queue entries are checked before any remote push work begins
- if a scene queue entry has `entityRevision < current local revision`, it is treated as stale
- stale scene queue entries are removed from the local queue without being pushed
- because they are removed before the network request starts, stale scene entries cannot overwrite newer local or remote revisions
- if an unexpected scene queue entry ever has `entityRevision > current local revision`, it is also discarded conservatively and never pushed

## Versioning Mechanism Used For Scenes

Scene versioning now uses a monotonic integer revision counter.

Relevant scene fields:

- `revision`
  - local scene revision
  - incremented on every persisted local scene edit save
- `remoteRevision`
  - last known remote scene revision successfully applied or synced
- `updatedAt`
  - retained for diagnostics only
- `lastSyncedAt`
  - retained for diagnostics only
- `remoteUpdatedAt`
  - retained for diagnostics only
- `lastEditedDeviceId`
  - local device identity used to stamp edits

Current rules:

- every persisted scene edit increments `revision`
- sync comparisons for scenes use revision rather than timestamps
- timestamps remain useful for logs, diagnostics, and UI inspection only

## How Conflicts Are Detected

Conflicts are only detected for scenes in the current Milestone 4 implementation.

A scene conflict is detected when:

1. there is both a local scene and a remote scene with the same remote identity
2. a previous scene sync baseline exists in `remoteRevision`
3. the local scene has changed past that baseline
   - `local.revision > local.remoteRevision`
4. the remote scene has also changed past that baseline
   - `remote.revision > local.remoteRevision`

When all of those are true, the sync layer treats the scene as conflicted and refuses to overwrite either prose version.

The implementation does not attempt automatic prose merge.

## How Conflicts Are Stored Locally

Conflicts are preserved locally using scene metadata plus a preserved copy strategy.

Conflict-related scene fields:

- `conflictState`
  - `none`
  - `local`
  - `remote_copy`
- `conflictGroupId`
- `remoteOriginalId`
- `syncSuppressed`

When a conflict is detected:

- the existing local scene is preserved in place
- that local scene is marked with:
  - `conflictState = local`
  - `syncStatus = conflict`
  - a generated `conflictGroupId`
- a second local scene is created for the remote version
- the remote copy is marked with:
  - `conflictState = remote_copy`
  - the same `conflictGroupId`
  - `remoteOriginalId = <remote scene id>`
  - `syncSuppressed = true`

This keeps both versions available locally without destructive overwrite.

## How Retries Are Handled If A Network Request Fails

Retries are currently basic and durable.

On sync failure:

- the queue entry is left in `syncQueue`
- `attemptCount` is incremented
- `lastAttemptAt` is updated
- `lastError` is stored
- the affected entity is marked with:
  - `syncStatus = sync_failed`
  - `syncError = <error message>`

The failed entry will be retried later when sync runs again:

- on app launch
- on reconnect
- on the background sync interval
- on manual sync

There is currently no exponential backoff or retry throttling beyond the normal sync cadence.

## How Remote Deletes Are Treated

Remote deletes are currently treated conservatively and non-destructively.

Current behavior:

- remote deletions are ignored
- missing remote rows are not interpreted as delete instructions
- local data is preserved

The same conservative rule currently applies to local deletes in reverse:

- local deletes are not pushed to the remote backend in v1

This avoids destructive data loss while the sync model is still intentionally minimal.
