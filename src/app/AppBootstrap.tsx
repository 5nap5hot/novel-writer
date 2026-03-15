import { useEffect } from "react";
import { Outlet, useLocation, useNavigate } from "react-router-dom";
import { useShallow } from "zustand/react/shallow";

import { useAppStore } from "../state/appStore";
import { SyncManager } from "../sync/SyncManager";
import { ThemeProvider } from "./theme";
import { mapSupabaseUser, subscribeToSupabaseAuth } from "../lib/supabase";

export function AppBootstrap() {
  const location = useLocation();
  const navigate = useNavigate();
  const {
    initialize,
    isBootstrapped,
    isLoading,
    authMode,
    currentUser,
    activeProject,
    selectedSceneId,
    completeSupabaseAuth,
    setCurrentUser
  } = useAppStore(useShallow((state) => ({
    initialize: state.initialize,
    isBootstrapped: state.isBootstrapped,
    isLoading: state.isLoading,
    authMode: state.authMode,
    currentUser: state.currentUser,
    activeProject: state.activeProject,
    selectedSceneId: state.selectedSceneId,
    completeSupabaseAuth: state.completeSupabaseAuth,
    setCurrentUser: state.setCurrentUser
  })));

  useEffect(() => {
    const shouldRestoreWorkspace =
      location.pathname === "/" || location.pathname === "/projects";
    void initialize({ restoreWorkspace: shouldRestoreWorkspace });
  }, [initialize]);

  useEffect(() => {
    const subscription = subscribeToSupabaseAuth((session) => {
      const storeState = useAppStore.getState();
      if (storeState.authMode !== "supabase") {
        return;
      }

      const user = mapSupabaseUser(session?.user ?? null);
      const currentUser = storeState.currentUser;

      if (
        (user === null && currentUser === null) ||
        (user !== null &&
          currentUser !== null &&
          user.id === currentUser.id &&
          user.email === currentUser.email)
      ) {
        return;
      }

      if (user) {
        void setCurrentUser(user);
        return;
      }

      void setCurrentUser(null);
    });

    return () => {
      subscription?.unsubscribe();
    };
  }, [completeSupabaseAuth, setCurrentUser]);

  useEffect(() => {
    if (!isBootstrapped || isLoading) {
      return;
    }

    if (authMode === "supabase" && !currentUser && location.pathname !== "/login") {
      navigate("/login", { replace: true });
      return;
    }

    if (location.pathname !== "/") {
      return;
    }

    if (authMode === "supabase" && !currentUser) {
      navigate("/login", { replace: true });
      return;
    }

    if (activeProject && selectedSceneId) {
      navigate(`/projects/${activeProject.id}/scenes/${selectedSceneId}`, {
        replace: true
      });
      return;
    }

    if (activeProject) {
      navigate(`/projects/${activeProject.id}`, { replace: true });
      return;
    }

    navigate("/projects", { replace: true });
  }, [activeProject, authMode, currentUser, isBootstrapped, isLoading, location.pathname, navigate, selectedSceneId]);

  if (!isBootstrapped || isLoading) {
    return (
      <ThemeProvider>
        <div className="app-loading">Loading Novel Writer...</div>
      </ThemeProvider>
    );
  }

  return (
    <ThemeProvider>
      <SyncManager />
      <Outlet />
    </ThemeProvider>
  );
}
