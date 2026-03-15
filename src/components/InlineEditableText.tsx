import { useEffect, useRef, useState } from "react";

interface InlineEditableTextProps {
  value: string;
  className?: string;
  placeholder?: string;
  onCommit: (value: string) => void;
  activationMode?: "always" | "double_click";
  onSingleClick?: () => void;
}

export function InlineEditableText({
  value,
  className,
  placeholder,
  onCommit,
  activationMode = "always",
  onSingleClick
}: InlineEditableTextProps) {
  const [draft, setDraft] = useState(value);
  const [isEditing, setIsEditing] = useState(activationMode === "always");
  const inputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    setDraft(value);
  }, [value]);

  useEffect(() => {
    if (activationMode === "always") {
      setIsEditing(true);
      return;
    }

    if (isEditing) {
      requestAnimationFrame(() => {
        inputRef.current?.focus();
        inputRef.current?.select();
      });
    }
  }, [activationMode, isEditing]);

  if (activationMode === "double_click" && !isEditing) {
    return (
      <button
        className={className}
        type="button"
        onClick={onSingleClick}
        onDoubleClick={() => setIsEditing(true)}
      >
        {value || placeholder}
      </button>
    );
  }

  return (
    <input
      ref={inputRef}
      className={className}
      value={draft}
      placeholder={placeholder}
      onChange={(event) => setDraft(event.target.value)}
      onBlur={() => {
        const nextValue = draft.trim() || value;
        if (nextValue !== value) {
          onCommit(nextValue);
        }
        setDraft(nextValue);
        if (activationMode === "double_click") {
          setIsEditing(false);
        }
      }}
      onKeyDown={(event) => {
        if (event.key === "Enter") {
          event.currentTarget.blur();
        }
        if (event.key === "Escape") {
          setDraft(value);
          if (activationMode === "double_click") {
            setIsEditing(false);
          }
          event.currentTarget.blur();
        }
      }}
    />
  );
}
