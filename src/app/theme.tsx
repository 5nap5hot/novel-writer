import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode
} from "react";

export type ThemeMode = "dark" | "light";

const THEME_STORAGE_KEY = "themeMode";

interface ThemeContextValue {
  themeMode: ThemeMode;
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [themeMode, setThemeMode] = useState<ThemeMode>(() => {
    if (typeof window === "undefined") {
      return "dark";
    }

    const storedTheme = window.localStorage.getItem(THEME_STORAGE_KEY);
    return storedTheme === "light" ? "light" : "dark";
  });

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    window.localStorage.setItem(THEME_STORAGE_KEY, themeMode);
    document.documentElement.classList.remove("dark-theme", "light-theme");
    document.documentElement.classList.add(`${themeMode}-theme`);
  }, [themeMode]);

  const value = useMemo<ThemeContextValue>(() => ({
    themeMode,
    toggleTheme: () => {
      setThemeMode((current) => (current === "dark" ? "light" : "dark"));
    }
  }), [themeMode]);

  return (
    <ThemeContext.Provider value={value}>
      <div className={`app-root ${themeMode}-theme`}>{children}</div>
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used within ThemeProvider.");
  }

  return context;
}
