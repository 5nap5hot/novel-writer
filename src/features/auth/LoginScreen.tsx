import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useShallow } from "zustand/react/shallow";

import { AppHeader } from "../../components/AppHeader";
import { getSupabaseClient } from "../../lib/supabase";
import { useAppStore } from "../../state/appStore";

export function LoginScreen() {
  const navigate = useNavigate();
  const {
    authMode,
    currentUser,
    setAuthMode,
    completeSupabaseAuth
  } = useAppStore(useShallow((state) => ({
    authMode: state.authMode,
    currentUser: state.currentUser,
    setAuthMode: state.setAuthMode,
    completeSupabaseAuth: state.completeSupabaseAuth
  })));
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [messageTone, setMessageTone] = useState<"info" | "success" | "error">("info");
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (authMode === "supabase" && currentUser) {
      navigate("/projects", { replace: true });
    }
  }, [authMode, currentUser, navigate]);

  async function handleSupabaseAuth(mode: "sign-in" | "sign-up") {
    const client = getSupabaseClient();

    if (!client) {
      setMessageTone("error");
      setMessage("Add VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to enable Supabase auth.");
      return;
    }

    setIsSubmitting(true);
    setMessage(null);

    const action =
      mode === "sign-in"
        ? client.auth.signInWithPassword({ email, password })
        : client.auth.signUp({ email, password });

    const { error } = await action;

    if (error) {
      setMessageTone("error");
      setMessage(error.message);
      setIsSubmitting(false);
      return;
    }

    await completeSupabaseAuth();
    setMessageTone("success");
    setMessage(mode === "sign-in" ? "Signed in with Supabase." : "Account created. Check your email if confirmation is enabled.");
    setIsSubmitting(false);
  }

  async function handlePasswordReset() {
    const client = getSupabaseClient();
    if (!client) {
      setMessageTone("error");
      setMessage("Add VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to enable Supabase auth.");
      return;
    }

    if (!email.trim()) {
      setMessageTone("error");
      setMessage("Enter your email address first.");
      return;
    }

    setIsSubmitting(true);
    setMessage(null);
    const { error } = await client.auth.resetPasswordForEmail(email, {
      redirectTo: typeof window !== "undefined" ? `${window.location.origin}/login` : undefined
    });

    setIsSubmitting(false);
    setMessageTone(error ? "error" : "success");
    setMessage(error ? error.message : "Password reset email sent.");
  }

  async function handleLocalMode() {
    await setAuthMode("local");
    setMessageTone("info");
    setMessage("Local-only mode enabled. Your IndexedDB data will work without sync.");
  }

  return (
    <div className="page-shell">
      <AppHeader rightSlot={<Link className="secondary-button" to="/projects">Skip to Projects</Link>} />
      <main className="auth-layout">
        <section className="hero-card">
          <p className="section-label">Milestone 1</p>
          <h1>Write locally first, connect sync later.</h1>
          <p className="hero-copy">
            Novel Writer stores projects, chapters, scenes, and UI state in IndexedDB first.
            Supabase auth is ready for the next sync milestone, but not required to start writing.
          </p>
        </section>

        <section className="panel auth-panel">
          <div className="panel-heading">
            <h2>Login</h2>
            <p>Sign in to sync your projects across devices, or keep writing locally on this machine.</p>
          </div>

          <label className="field">
            <span>Email</span>
            <input
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="writer@example.com"
            />
          </label>

          <label className="field">
            <span>Password</span>
            <input
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder="••••••••"
            />
          </label>

          <div className="button-row">
            <button onClick={() => void handleSupabaseAuth("sign-in")} disabled={isSubmitting}>
              {isSubmitting ? "Working..." : "Sign In"}
            </button>
            <button className="secondary-button" onClick={() => void handleSupabaseAuth("sign-up")} disabled={isSubmitting}>
              Sign Up
            </button>
            <button className="secondary-button" onClick={() => void handlePasswordReset()} disabled={isSubmitting}>
              Reset Password
            </button>
            <button className="ghost-button" onClick={() => void handleLocalMode()}>
              Continue Locally
            </button>
          </div>

          {message ? <p className={`auth-message is-${messageTone}`}>{message}</p> : null}
        </section>
      </main>
    </div>
  );
}
