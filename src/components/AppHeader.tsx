import type { ReactNode } from "react";
import { Link } from "react-router-dom";

interface AppHeaderProps {
  rightSlot?: ReactNode;
}

export function AppHeader({ rightSlot }: AppHeaderProps) {
  return (
    <header className="app-header">
      <div>
        <p className="app-eyebrow">Desktop-first drafting workspace</p>
        <Link to="/projects" className="app-title-link">
          Novel Writer
        </Link>
      </div>
      <div className="app-header-actions">{rightSlot}</div>
    </header>
  );
}
