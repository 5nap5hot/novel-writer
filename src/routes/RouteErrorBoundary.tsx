import { Link, isRouteErrorResponse, useRouteError } from "react-router-dom";

export function RouteErrorBoundary() {
  const error = useRouteError();

  let title = "Unexpected error";
  let message = "Novel Writer hit a runtime error while rendering this route.";

  if (isRouteErrorResponse(error)) {
    title = `${error.status} ${error.statusText}`;
    message =
      typeof error.data === "string"
        ? error.data
        : "The route failed while loading or rendering.";
  } else if (error instanceof Error) {
    message = error.message;
  }

  return (
    <div className="page-shell">
      <main className="page-content">
        <section className="panel empty-state">
          <h1>{title}</h1>
          <p>{message}</p>
          <Link className="secondary-button" to="/projects">
            Back to Projects
          </Link>
        </section>
      </main>
    </div>
  );
}
