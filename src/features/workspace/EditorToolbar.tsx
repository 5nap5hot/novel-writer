import { useEffect, useRef, useState, type ReactNode } from "react";
import type { Editor } from "@tiptap/react";
import {
  type FontSizePreset,
  type LineSpacingPreset
} from "../../lib/editorContent";

const FONT_SIZE_PRESETS = [
  { label: "Small", value: "sm" },
  { label: "Medium", value: "md" },
  { label: "Large", value: "lg" },
  { label: "XL", value: "xl" }
];

const LINE_SPACING_PRESETS = [
  { label: "Single", value: "normal" },
  { label: "1.5", value: "relaxed" },
  { label: "Double", value: "double" }
];

const TOOLBAR_LABELS_STORAGE_KEY = "showToolbarLabels";

interface EditorToolbarProps {
  editor: Editor | null;
  zoomPercent: number;
  onZoomChange: (zoomPercent: number) => void;
  onCopyCurrentScope?: () => void;
  onOpenAtlasView?: () => void;
  isDisabled?: boolean;
}

export function EditorToolbar({
  editor,
  zoomPercent,
  onZoomChange,
  onCopyCurrentScope,
  onOpenAtlasView,
  isDisabled = false
}: EditorToolbarProps) {
  const [showLabels, setShowLabels] = useState<boolean>(() => {
    if (typeof window === "undefined") {
      return true;
    }

    return window.localStorage.getItem(TOOLBAR_LABELS_STORAGE_KEY) !== "false";
  });

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    window.localStorage.setItem(TOOLBAR_LABELS_STORAGE_KEY, showLabels ? "true" : "false");
  }, [showLabels]);

  if (!editor) {
    return null;
  }

  return (
    <div className="editor-toolbar">
      <div className="toolbar-group">
        <ToolbarIconButton
          icon={<BoldIcon />}
          label="Bold"
          showLabel={showLabels}
          isActive={!isDisabled && editor.isActive("bold")}
          isDisabled={isDisabled}
          onClick={() => editor.chain().focus().toggleBold().run()}
        />
        <ToolbarIconButton
          icon={<ItalicIcon />}
          label="Italic"
          showLabel={showLabels}
          isActive={!isDisabled && editor.isActive("italic")}
          isDisabled={isDisabled}
          onClick={() => editor.chain().focus().toggleItalic().run()}
        />
        <ToolbarIconButton
          icon={<UnderlineIcon />}
          label="Underline"
          showLabel={showLabels}
          isActive={!isDisabled && editor.isActive("underline")}
          isDisabled={isDisabled}
          onClick={() => editor.chain().focus().toggleUnderline().run()}
        />
        <ToolbarIconButton
          icon={<BulletListIcon />}
          label="List"
          showLabel={showLabels}
          isActive={!isDisabled && editor.isActive("bulletList")}
          isDisabled={isDisabled}
          onClick={() => editor.chain().focus().toggleBulletList().run()}
        />
      </div>

      <div className="toolbar-group">
        <ToolbarIconButton
          icon={<AlignLeftIcon />}
          label="Left"
          showLabel={showLabels}
          isActive={!isDisabled && editor.isActive({ textAlign: "left" })}
          isDisabled={isDisabled}
          onClick={() => editor.chain().focus().setTextAlign("left").run()}
        />
        <ToolbarIconButton
          icon={<AlignCenterIcon />}
          label="Centre"
          showLabel={showLabels}
          isActive={!isDisabled && editor.isActive({ textAlign: "center" })}
          isDisabled={isDisabled}
          onClick={() => editor.chain().focus().setTextAlign("center").run()}
        />
        <ToolbarIconButton
          icon={<AlignRightIcon />}
          label="Right"
          showLabel={showLabels}
          isActive={!isDisabled && editor.isActive({ textAlign: "right" })}
          isDisabled={isDisabled}
          onClick={() => editor.chain().focus().setTextAlign("right").run()}
        />
        <ToolbarIconButton
          icon={<AlignJustifyIcon />}
          label="Justify"
          showLabel={showLabels}
          isActive={!isDisabled && editor.isActive({ textAlign: "justify" })}
          isDisabled={isDisabled}
          onClick={() => editor.chain().focus().setTextAlign("justify").run()}
        />
      </div>

      <div className="toolbar-group">
        <ToolbarIconButton
          icon={<UndoIcon />}
          label="Undo"
          showLabel={showLabels}
          isDisabled={isDisabled || !editor.can().undo()}
          onClick={() => editor.chain().focus().undo().run()}
        />
        <ToolbarIconButton
          icon={<RedoIcon />}
          label="Redo"
          showLabel={showLabels}
          isDisabled={isDisabled || !editor.can().redo()}
          onClick={() => editor.chain().focus().redo().run()}
        />

        <ToolbarMenuButton
          icon={<FontSizeIcon />}
          label="Font size"
          showLabel={showLabels}
          isDisabled={isDisabled}
          options={FONT_SIZE_PRESETS.map((preset) => ({
            label: preset.label,
            isActive: ((editor.getAttributes("textStyle").fontSize as FontSizePreset | undefined) ?? "md") === preset.value,
            onSelect: () => editor.chain().focus().setFontSize(preset.value as FontSizePreset).run()
          }))}
        />

        <ToolbarMenuButton
          icon={<LineSpacingIcon />}
          label="Line spacing"
          showLabel={showLabels}
          isDisabled={isDisabled}
          options={LINE_SPACING_PRESETS.map((preset) => ({
            label: preset.label,
            isActive: ((editor.getAttributes("paragraph").lineHeight as LineSpacingPreset | undefined) ?? "normal") === preset.value,
            onSelect: () => editor.chain().focus().setLineHeight(preset.value as LineSpacingPreset).run()
          }))}
        />

        <input
          className="toolbar-color-input"
          type="color"
          value={normalizeColor((editor.getAttributes("textStyle").color as string | undefined) ?? "#2b2118")}
          disabled={isDisabled}
          onChange={(event) => editor.chain().focus().setColor(event.target.value).run()}
          aria-label="Text color"
        />
      </div>

      <div className="toolbar-group toolbar-zoom">
        {onOpenAtlasView ? (
          <ToolbarIconButton
            icon={<AtlasViewIcon />}
            label="Atlas view"
            showLabel={showLabels}
            isDisabled={isDisabled}
            onClick={onOpenAtlasView}
          />
        ) : null}
        {onCopyCurrentScope ? (
          <ToolbarIconButton
            icon={<CopyIcon />}
            label="Copy scope"
            showLabel={showLabels}
            isDisabled={isDisabled}
            onClick={onCopyCurrentScope}
          />
        ) : null}
        <ToolbarIconButton
          icon={<ZoomOutIcon />}
          label="Zoom out"
          showLabel={showLabels}
          isDisabled={isDisabled}
          onClick={() => onZoomChange(zoomPercent - 10)}
        />
        <span className="zoom-label">{zoomPercent}%</span>
        <ToolbarIconButton
          icon={<ZoomInIcon />}
          label="Zoom in"
          showLabel={showLabels}
          isDisabled={isDisabled}
          onClick={() => onZoomChange(zoomPercent + 10)}
        />
        <ToolbarIconButton
          icon={<LabelToggleIcon />}
          label={showLabels ? "Hide labels" : "Show labels"}
          showLabel={showLabels}
          isActive={showLabels}
          onClick={() => setShowLabels((current) => !current)}
        />
      </div>
    </div>
  );
}

interface ToolbarIconButtonProps {
  icon: ReactNode;
  label: string;
  showLabel: boolean;
  isActive?: boolean;
  isDisabled?: boolean;
  ariaLabel?: string;
  onClick: () => void;
}

function ToolbarIconButton({
  icon,
  label,
  showLabel,
  isActive = false,
  isDisabled = false,
  ariaLabel,
  onClick
}: ToolbarIconButtonProps) {
  return (
    <button
      className={`toolbar-button icon-toolbar-button ${isActive ? "is-active" : ""} ${showLabel ? "show-label" : "hide-label"}`}
      onClick={onClick}
      type="button"
      disabled={isDisabled}
      aria-label={ariaLabel ?? label}
      title={label}
    >
      <span className="toolbar-button-icon" aria-hidden="true">
        {icon}
      </span>
      {showLabel ? <span className="toolbar-button-label">{label}</span> : null}
    </button>
  );
}

function ToolbarSvg({ children }: { children: ReactNode }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className="toolbar-svg-icon"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}

interface ToolbarMenuButtonProps {
  icon: ReactNode;
  label: string;
  showLabel: boolean;
  isDisabled?: boolean;
  options: Array<{
    label: string;
    isActive?: boolean;
    onSelect: () => void;
  }>;
}

function ToolbarMenuButton({
  icon,
  label,
  showLabel,
  isDisabled = false,
  options
}: ToolbarMenuButtonProps) {
  const [isOpen, setIsOpen] = useState(false);
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

  return (
    <div ref={rootRef} className="toolbar-menu-shell">
      <ToolbarIconButton
        icon={icon}
        label={label}
        showLabel={showLabel}
        isDisabled={isDisabled}
        onClick={() => setIsOpen((current) => !current)}
      />
      {isOpen ? (
        <div className="toolbar-menu-popover">
          {options.map((option) => (
            <button
              key={option.label}
              className={`toolbar-menu-item ${option.isActive ? "is-active" : ""}`}
              type="button"
              onClick={() => {
                option.onSelect();
                setIsOpen(false);
              }}
            >
              {option.label}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function BoldIcon() {
  return (
    <ToolbarSvg>
      <path d="M8 5h6a4 4 0 0 1 0 8H8z" />
      <path d="M8 13h7a4 4 0 0 1 0 8H8z" />
    </ToolbarSvg>
  );
}

function ItalicIcon() {
  return (
    <ToolbarSvg>
      <line x1="14" y1="4" x2="10" y2="20" />
      <line x1="8" y1="4" x2="16" y2="4" />
      <line x1="8" y1="20" x2="16" y2="20" />
    </ToolbarSvg>
  );
}

function UnderlineIcon() {
  return (
    <ToolbarSvg>
      <path d="M8 4v6a4 4 0 0 0 8 0V4" />
      <line x1="5" y1="20" x2="19" y2="20" />
    </ToolbarSvg>
  );
}

function BulletListIcon() {
  return (
    <ToolbarSvg>
      <circle cx="6" cy="7" r="1.2" fill="currentColor" stroke="none" />
      <circle cx="6" cy="12" r="1.2" fill="currentColor" stroke="none" />
      <circle cx="6" cy="17" r="1.2" fill="currentColor" stroke="none" />
      <line x1="10" y1="7" x2="18" y2="7" />
      <line x1="10" y1="12" x2="18" y2="12" />
      <line x1="10" y1="17" x2="18" y2="17" />
    </ToolbarSvg>
  );
}

function AlignLeftIcon() {
  return (
    <ToolbarSvg>
      <line x1="5" y1="7" x2="19" y2="7" />
      <line x1="5" y1="12" x2="15" y2="12" />
      <line x1="5" y1="17" x2="18" y2="17" />
    </ToolbarSvg>
  );
}

function AlignCenterIcon() {
  return (
    <ToolbarSvg>
      <line x1="5" y1="7" x2="19" y2="7" />
      <line x1="7" y1="12" x2="17" y2="12" />
      <line x1="6" y1="17" x2="18" y2="17" />
    </ToolbarSvg>
  );
}

function AlignRightIcon() {
  return (
    <ToolbarSvg>
      <line x1="5" y1="7" x2="19" y2="7" />
      <line x1="9" y1="12" x2="19" y2="12" />
      <line x1="6" y1="17" x2="19" y2="17" />
    </ToolbarSvg>
  );
}

function AlignJustifyIcon() {
  return (
    <ToolbarSvg>
      <line x1="5" y1="7" x2="19" y2="7" />
      <line x1="5" y1="12" x2="19" y2="12" />
      <line x1="5" y1="17" x2="19" y2="17" />
    </ToolbarSvg>
  );
}

function UndoIcon() {
  return (
    <ToolbarSvg>
      <path d="M9 8H5V4" />
      <path d="M5 8a8 8 0 1 1 1 11" />
    </ToolbarSvg>
  );
}

function RedoIcon() {
  return (
    <ToolbarSvg>
      <path d="M15 8h4V4" />
      <path d="M19 8a8 8 0 1 0-1 11" />
    </ToolbarSvg>
  );
}

function ZoomOutIcon() {
  return (
    <ToolbarSvg>
      <circle cx="11" cy="11" r="6" />
      <line x1="16.5" y1="16.5" x2="20" y2="20" />
      <line x1="8" y1="11" x2="14" y2="11" />
    </ToolbarSvg>
  );
}

function ZoomInIcon() {
  return (
    <ToolbarSvg>
      <circle cx="11" cy="11" r="6" />
      <line x1="16.5" y1="16.5" x2="20" y2="20" />
      <line x1="8" y1="11" x2="14" y2="11" />
      <line x1="11" y1="8" x2="11" y2="14" />
    </ToolbarSvg>
  );
}

function CopyIcon() {
  return (
    <ToolbarSvg>
      <rect x="9" y="9" width="10" height="10" rx="2" />
      <path d="M7 15H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v1" />
    </ToolbarSvg>
  );
}

function AtlasViewIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="toolbar-svg-icon" aria-hidden="true">
      <rect x="4" y="5" width="16" height="14" rx="2" />
      <path d="M8 9h8" />
      <path d="M8 12h8" />
      <path d="M8 15h5" />
    </svg>
  );
}

function LabelToggleIcon() {
  return (
    <ToolbarSvg>
      <rect x="4" y="5" width="16" height="14" rx="2" />
      <line x1="8" y1="10" x2="16" y2="10" />
      <line x1="8" y1="14" x2="13" y2="14" />
    </ToolbarSvg>
  );
}

function FontSizeIcon() {
  return (
    <ToolbarSvg>
      <path d="M7 18 12 6l5 12" />
      <path d="M8.5 14h7" />
    </ToolbarSvg>
  );
}

function LineSpacingIcon() {
  return (
    <ToolbarSvg>
      <path d="M8 7h10" />
      <path d="M8 12h10" />
      <path d="M8 17h10" />
      <path d="m4.5 5.5-2 2 2 2" />
      <path d="m2.5 7.5h3.5" />
      <path d="m4.5 14.5-2 2 2 2" />
      <path d="m2.5 16.5h3.5" />
    </ToolbarSvg>
  );
}

function normalizeColor(color: string): string {
  if (color.startsWith("#") && (color.length === 7 || color.length === 4)) {
    return color;
  }

  return "#2b2118";
}
