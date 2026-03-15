import { useTheme } from "../app/theme";

export function ThemeToggleButton() {
  const { themeMode, toggleTheme } = useTheme();

  return (
    <button
      className="icon-menu-button"
      type="button"
      onClick={toggleTheme}
      aria-label={themeMode === "dark" ? "Switch to light mode" : "Switch to dark mode"}
      title={themeMode === "dark" ? "Light mode" : "Dark mode"}
    >
      {themeMode === "dark" ? <SunIcon /> : <MoonIcon />}
    </button>
  );
}

function MoonIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M19 13a7 7 0 1 1-8-8 6 6 0 0 0 8 8z" />
    </svg>
  );
}

function SunIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="4" />
      <line x1="12" y1="2.5" x2="12" y2="5" />
      <line x1="12" y1="19" x2="12" y2="21.5" />
      <line x1="2.5" y1="12" x2="5" y2="12" />
      <line x1="19" y1="12" x2="21.5" y2="12" />
      <line x1="5.5" y1="5.5" x2="7.2" y2="7.2" />
      <line x1="16.8" y1="16.8" x2="18.5" y2="18.5" />
      <line x1="16.8" y1="7.2" x2="18.5" y2="5.5" />
      <line x1="5.5" y1="18.5" x2="7.2" y2="16.8" />
    </svg>
  );
}
