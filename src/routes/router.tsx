import { createBrowserRouter, Navigate } from "react-router-dom";

import { AppBootstrap } from "../app/AppBootstrap";
import { LoginScreen } from "../features/auth/LoginScreen";
import { ProjectListScreen } from "../features/projects/ProjectListScreen";
import { WorkspaceScreen } from "../features/workspace/WorkspaceScreen";
import { RouteErrorBoundary } from "./RouteErrorBoundary";

export const router = createBrowserRouter([
  {
    path: "/",
    element: <AppBootstrap />,
    errorElement: <RouteErrorBoundary />,
    children: [
      {
        index: true,
        element: <div />
      },
      {
        path: "login",
        element: <LoginScreen />
      },
      {
        path: "projects",
        element: <ProjectListScreen />
      },
      {
        path: "projects/:projectId",
        element: <WorkspaceScreen />
      },
      {
        path: "projects/:projectId/scenes/:sceneId",
        element: <WorkspaceScreen />
      }
    ]
  },
  {
    path: "*",
    element: <Navigate to="/" replace />,
    errorElement: <RouteErrorBoundary />
  }
]);
