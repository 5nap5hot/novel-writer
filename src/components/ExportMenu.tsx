import { useEffect, useRef, useState } from "react";

import {
  exportProjectSafetyZip,
  exportProjectScrivenerDocx
} from "../export/service";

interface ExportMenuProps {
  projectId: string;
}

export function ExportMenu({ projectId }: ExportMenuProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [isExporting, setIsExporting] = useState<null | "zip" | "docx">(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const rootRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!isOpen) {
      return;
    }

    const handlePointerDown = (event: MouseEvent) => {
      const target = event.target as Node | null;
      if (target && rootRef.current?.contains(target)) {
        return;
      }

      setIsOpen(false);
    };

    document.addEventListener("mousedown", handlePointerDown, true);
    return () => {
      document.removeEventListener("mousedown", handlePointerDown, true);
    };
  }, [isOpen]);

  async function handleExport(mode: "zip" | "docx") {
    setErrorMessage(null);
    setIsExporting(mode);

    try {
      if (mode === "zip") {
        await exportProjectSafetyZip(projectId);
      } else {
        await exportProjectScrivenerDocx(projectId);
      }
      setIsOpen(false);
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : "Export failed.");
    } finally {
      setIsExporting(null);
    }
  }

  return (
    <div ref={rootRef} className="header-menu-shell">
      <button
        className="icon-menu-button"
        type="button"
        aria-label="Export project"
        title="Export"
        onClick={() => setIsOpen((current) => !current)}
      >
        <ExportIcon />
      </button>

      {isOpen ? (
        <div className="header-menu-popover export-menu-popover">
          <button
            className="header-menu-item"
            type="button"
            disabled={isExporting !== null}
            onClick={() => void handleExport("zip")}
          >
            <strong>Safety ZIP</strong>
            <span>{isExporting === "zip" ? "Exporting..." : "Binder-shaped Markdown archive"}</span>
          </button>
          <button
            className="header-menu-item"
            type="button"
            disabled={isExporting !== null}
            onClick={() => void handleExport("docx")}
          >
            <strong>Scrivener DOCX</strong>
            <span>{isExporting === "docx" ? "Exporting..." : "Single manuscript document"}</span>
          </button>
          {errorMessage ? <div className="export-error">{errorMessage}</div> : null}
        </div>
      ) : null}
    </div>
  );
}

function ExportIcon() {
  return (
    <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M10 3.5v8" />
      <path d="m6.75 8.75 3.25 3.25 3.25-3.25" />
      <path d="M4 14.75h12" />
    </svg>
  );
}
