import { createClient, type Session, type SupabaseClient, type User } from "@supabase/supabase-js";

import type { AuthenticatedUser } from "../types/models";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

let client: SupabaseClient | null = null;

export function getSupabaseClient(): SupabaseClient | null {
  if (!supabaseUrl || !supabaseAnonKey) {
    return null;
  }

  if (!client) {
    client = createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true
      }
    });
  }

  return client;
}

export async function getSupabaseAuthUser(): Promise<AuthenticatedUser | null> {
  const client = getSupabaseClient();
  if (!client) {
    return null;
  }

  const {
    data: { session }
  } = await client.auth.getSession();

  return mapSupabaseUser(session?.user ?? null);
}

export function mapSupabaseUser(user: User | null | undefined): AuthenticatedUser | null {
  if (!user) {
    return null;
  }

  return {
    id: user.id,
    email: user.email ?? null
  };
}

export function subscribeToSupabaseAuth(
  callback: (session: Session | null) => void
): { unsubscribe: () => void } | null {
  const client = getSupabaseClient();
  if (!client) {
    return null;
  }

  const {
    data: { subscription }
  } = client.auth.onAuthStateChange((_event, session) => {
    callback(session);
  });

  return {
    unsubscribe: () => subscription.unsubscribe()
  };
}
