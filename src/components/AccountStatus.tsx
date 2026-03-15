import { useEffect, useRef, useState } from "react";

import type { AuthenticatedUser } from "../types/models";

interface AccountStatusProps {
  authMode: "local" | "supabase";
  currentUser: AuthenticatedUser | null;
  onSignOut?: () => void;
}

export function AccountStatus({ authMode, currentUser, onSignOut }: AccountStatusProps) {
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

  const label = authMode === "supabase" && currentUser
    ? currentUser.email ?? currentUser.id
    : "Writing stays on this device";
  const eyebrow = authMode === "supabase" && currentUser ? "Cloud account" : "Local mode";

  return (
    <div ref={rootRef} className="header-menu-shell">
      <button
        className="icon-menu-button"
        type="button"
        aria-label="Account"
        title={eyebrow}
        onClick={() => setIsOpen((current) => !current)}
      >
        <UserIcon />
      </button>

      {isOpen ? (
        <div className="header-menu-popover account-menu-popover">
          <div className="account-menu-summary">
            <span className="account-status-label">{eyebrow}</span>
            <span className="account-status-value">{label}</span>
          </div>
          {authMode === "supabase" && currentUser && onSignOut ? (
            <button
              className="header-menu-item account-menu-action"
              type="button"
              onClick={() => {
                setIsOpen(false);
                onSignOut();
              }}
            >
              <strong>Sign out</strong>
              <span>Disconnect this device from your cloud account</span>
            </button>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function UserIcon() {
  return (
    <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="10" cy="6.5" r="3" />
      <path d="M4.75 16c1.2-2.3 3.1-3.45 5.25-3.45S14.05 13.7 15.25 16" />
    </svg>
  );
}
