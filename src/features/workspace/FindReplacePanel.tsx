import { useEffect, useRef, useState, type MouseEvent as ReactMouseEvent } from "react";

import type { SearchMode, SearchOptions, SearchScope } from "./searchUtils";

interface FindReplacePanelProps {
  isOpen: boolean;
  options: SearchOptions;
  foundCount: number;
  currentMatchNumber: number;
  replacedCount: number;
  onClose: () => void;
  onOptionsChange: (patch: Partial<SearchOptions>) => void;
  onNext: () => void;
  onPrevious: () => void;
  onReplace: () => void;
  onReplaceAndFind: () => void;
  onReplaceAll: () => void;
}

export function FindReplacePanel({
  isOpen,
  options,
  foundCount,
  currentMatchNumber,
  replacedCount,
  onClose,
  onOptionsChange,
  onNext,
  onPrevious,
  onReplace,
  onReplaceAndFind,
  onReplaceAll
}: FindReplacePanelProps) {
  const panelRef = useRef<HTMLDivElement | null>(null);
  const findInputRef = useRef<HTMLInputElement | null>(null);
  const dragOffsetRef = useRef<{ x: number; y: number } | null>(null);
  const [position, setPosition] = useState({ top: 108, left: 820 });

  useEffect(() => {
    if (!isOpen) {
      return;
    }

    const focusTimer = window.setTimeout(() => {
      findInputRef.current?.focus();
      findInputRef.current?.select();
    }, 0);

    return () => {
      window.clearTimeout(focusTimer);
    };
  }, [isOpen]);

  useEffect(() => {
    if (!isOpen) {
      return;
    }

    const handleMouseMove = (event: MouseEvent) => {
      if (!dragOffsetRef.current) {
        return;
      }

      setPosition({
        top: Math.max(24, event.clientY - dragOffsetRef.current.y),
        left: Math.max(24, event.clientX - dragOffsetRef.current.x)
      });
    };

    const handleMouseUp = () => {
      dragOffsetRef.current = null;
    };

    window.addEventListener("mousemove", handleMouseMove);
    window.addEventListener("mouseup", handleMouseUp);

    return () => {
      window.removeEventListener("mousemove", handleMouseMove);
      window.removeEventListener("mouseup", handleMouseUp);
    };
  }, [isOpen]);

  if (!isOpen) {
    return null;
  }

  function handleDragStart(event: ReactMouseEvent<HTMLDivElement>) {
    const rect = panelRef.current?.getBoundingClientRect();
    if (!rect) {
      return;
    }

    dragOffsetRef.current = {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top
    };
  }

  return (
    <div
      ref={panelRef}
      className="find-replace-panel"
      style={{
        top: `${position.top}px`,
        left: `${position.left}px`
      }}
    >
      <div className="find-replace-header" onMouseDown={handleDragStart}>
        <strong>Find / Replace</strong>
        <button className="ghost-button" type="button" onClick={onClose}>
          Close
        </button>
      </div>

      <div className="find-replace-body">
        <label className="field">
          <span>Find</span>
          <input
            ref={findInputRef}
            value={options.query}
            onChange={(event) => onOptionsChange({ query: event.target.value })}
          />
        </label>

        <label className="field">
          <span>Replace</span>
          <input
            value={options.replaceText}
            onChange={(event) => onOptionsChange({ replaceText: event.target.value })}
          />
        </label>

        <div className="find-replace-grid">
          <label className="field">
            <span>Scope</span>
            <select
              value={options.scope}
              onChange={(event) => onOptionsChange({ scope: event.target.value as SearchScope })}
            >
              <option value="selection">Current Selection</option>
              <option value="entire_project">Entire Project</option>
            </select>
          </label>

          <label className="field">
            <span>Mode</span>
            <select
              value={options.mode}
              onChange={(event) => onOptionsChange({ mode: event.target.value as SearchMode })}
            >
              <option value="contains">Contains</option>
              <option value="whole_word">Whole Word</option>
              <option value="starts_with">Starts With</option>
              <option value="ends_with">Ends With</option>
            </select>
          </label>
        </div>

        <div className="find-replace-options">
          <label>
            <input
              type="checkbox"
              checked={options.ignoreCase}
              onChange={(event) => onOptionsChange({ ignoreCase: event.target.checked })}
            />
            Ignore Case
          </label>
          <label>
            <input
              type="checkbox"
              checked={options.ignoreDiacritics}
              onChange={(event) => onOptionsChange({ ignoreDiacritics: event.target.checked })}
            />
            Ignore Diacritics
          </label>
        </div>

        <div className="find-replace-actions">
          <button type="button" onClick={onPrevious}>Previous</button>
          <button type="button" onClick={onNext}>Next</button>
          <button type="button" onClick={onReplace}>Replace</button>
          <button type="button" onClick={onReplaceAndFind}>Replace &amp; Find</button>
          <button type="button" onClick={onReplaceAll}>Replace All</button>
        </div>

        <div className="find-replace-status">
          <span>Found: {foundCount}</span>
          <span>Match: {currentMatchNumber} of {foundCount}</span>
          <span>Replaced: {replacedCount}</span>
        </div>
      </div>
    </div>
  );
}
