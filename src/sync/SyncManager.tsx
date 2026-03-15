import { useEffect } from "react";
import { useShallow } from "zustand/react/shallow";

import { useAppStore } from "../state/appStore";

const SYNC_INTERVAL_MS = 60_000;

export function SyncManager() {
  const {
    authMode,
    isBootstrapped,
    isOnline,
    runBackgroundSync,
    setOnlineStatus
  } = useAppStore(useShallow((state) => ({
    authMode: state.authMode,
    isBootstrapped: state.isBootstrapped,
    isOnline: state.isOnline,
    runBackgroundSync: state.runBackgroundSync,
    setOnlineStatus: state.setOnlineStatus
  })));

  useEffect(() => {
    const handleOnline = () => {
      void setOnlineStatus(true);
      void runBackgroundSync();
    };
    const handleOffline = () => {
      void setOnlineStatus(false);
    };

    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);

    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, [runBackgroundSync, setOnlineStatus]);

  useEffect(() => {
    if (!isBootstrapped || authMode !== "supabase" || !isOnline) {
      return;
    }

    void runBackgroundSync();

    const intervalId = window.setInterval(() => {
      void runBackgroundSync();
    }, SYNC_INTERVAL_MS);

    return () => {
      window.clearInterval(intervalId);
    };
  }, [authMode, isBootstrapped, isOnline, runBackgroundSync]);

  return null;
}
